import Foundation
import CryptoKit
import Combine

// MARK: - Revival Manifest Modelleri
struct RevivalManifest: Codable {
    let version: String
    let updatedAt: String
    let files: [RevivalSyncItem]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case files
    }
}

struct RevivalSyncItem: Codable {
    /// Hedef dosya yolu (örneğin: "Revival/Game/BinaryTr/dinput8.dll" veya "madeira.cfg")
    let targetPath: String
    /// İndirme URL'si (GitHub raw veya release asset)
    let url: String
    /// Doğrulama için SHA-256 hash'i (küçük harf hex)
    let sha256: String?
    /// Dosya boyutu (byte)
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case targetPath = "target_path"
        case url
        case sha256
        case size
    }
}

// MARK: - RevivalSyncEngine
/// GitHub üzerinden oyun dosyalarını, DLL'leri ve ayarları açılışta denetleyip güncelleyen motor.
@MainActor
final class RevivalSyncEngine: ObservableObject {
    static let shared = RevivalSyncEngine()

    @Published var isSyncing: Bool = false
    @Published var progressText: String = ""
    @Published var progressFraction: Double = 0.0
    @Published var syncError: String? = nil

    /// Varsayılan manifest URL'si (GitHub raw main branch)
    var manifestURL: URL = URL(string: "https://raw.githubusercontent.com/byKAYRA/rvll/main/manifest.json")!

    private init() {}

    /// Belgeler (Documents) dizini yolu
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Wine prefix drive_c dizini yolu
    private var driveCDirectory: URL {
        documentsDirectory.appendingPathComponent("wine/drive_c")
    }

    /// Güncelleme kontrolü ve indirme sürecini başlatır
    func synchronize() async {
        isSyncing = true
        progressFraction = 0.0
        progressText = "Güncellemeler denetleniyor..."
        syncError = nil

        do {
            // 1. Uzak manifest.json'u çek (3 saniye zaman aşımı ile)
            var request = URLRequest(url: manifestURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 5.0

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                finishWithOfflineMessage("Sunucuya erişilemedi, yerel dosyalarla başlanıyor.")
                return
            }

            let manifest = try JSONDecoder().decode(RevivalManifest.self, from: data)
            let items = manifest.files
            guard !items.isEmpty else {
                finishWithOfflineMessage("Tüm dosyalar güncel.")
                return
            }

            // 2. Güncellenmesi veya indirilmesi gereken dosyaları tespit et
            var itemsToDownload: [RevivalSyncItem] = []
            for item in items {
                let localURL = resolveLocalURL(for: item.targetPath)
                if needsDownload(localURL: localURL, expectedSha: item.sha256, expectedSize: item.size) {
                    itemsToDownload.append(item)
                }
            }

            if itemsToDownload.isEmpty {
                finishWithOfflineMessage("Tüm dosyalar güncel.")
                return
            }

            // 3. Dosyaları sırayla indir ve hedef konuma yerleştir
            let total = Double(itemsToDownload.count)
            for (index, item) in itemsToDownload.enumerated() {
                let filename = (item.targetPath as NSString).lastPathComponent
                progressText = "\(filename) indiriliyor (\(index + 1)/\(itemsToDownload.count))..."
                progressFraction = Double(index) / total

                guard let fileURL = URL(string: item.url) else { continue }
                let (downloadedTempURL, _) = try await URLSession.shared.download(from: fileURL)

                let destination = resolveLocalURL(for: item.targetPath)
                let parentDir = destination.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

                // Varsa eskisini kaldır, yenisini taşı
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.moveItem(at: downloadedTempURL, to: destination)

                // İsteğe bağlı SHA-256 doğrulama
                if let expectedSha = item.sha256, !expectedSha.isEmpty {
                    if let actualSha = computeSHA256(for: destination),
                       actualSha.caseInsensitiveCompare(expectedSha) != .orderedSame {
                        print("[RevivalSync] UYARI: \(filename) hash uyuşmazlığı (Beklenen: \(expectedSha), Alınan: \(actualSha))")
                    }
                }
            }

            progressFraction = 1.0
            progressText = "Güncellemeler tamamlandı."
        } catch {
            print("[RevivalSync] Senkronizasyon atlandı / hata: \(error.localizedDescription)")
            finishWithOfflineMessage("Çevrimdışı mod: yerel dosyalar başlatılıyor.")
        }

        try? await Task.sleep(nanoseconds: 300_000_000)
        isSyncing = false
    }

    private func finishWithOfflineMessage(_ msg: String) {
        progressFraction = 1.0
        progressText = msg
        isSyncing = false
    }

    /// targetPath'i iOS sandbox içindeki gerçek dosya yoluna dönüştürür.
    /// Eğer yol "madeira.cfg" ise Documents/ içine, "Revival/..." ise drive_c/ içine yerleştirir.
    func resolveLocalURL(for targetPath: String) -> URL {
        if targetPath == "madeira.cfg" || targetPath.hasPrefix("Documents/") {
            let clean = targetPath.replacingOccurrences(of: "Documents/", with: "")
            return documentsDirectory.appendingPathComponent(clean)
        }
        return driveCDirectory.appendingPathComponent(targetPath)
    }

    /// Dosyanın indirilmesi gerekip gerekmediğini denetler
    private func needsDownload(localURL: URL, expectedSha: String?, expectedSize: Int64?) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: localURL.path) else {
            return true // Dosya yok, indirilmeli
        }

        // Boyut kontrolü
        if let expectedSize = expectedSize, expectedSize > 0 {
            if let attrs = try? fm.attributesOfItem(atPath: localURL.path),
               let size = attrs[.size] as? Int64, size != expectedSize {
                return true
            }
        }

        // SHA-256 kontrolü (belirtilmişse)
        if let expectedSha = expectedSha, !expectedSha.isEmpty {
            if let actual = computeSHA256(for: localURL),
               actual.caseInsensitiveCompare(expectedSha) != .orderedSame {
                return true
            }
        }

        return false
    }

    /// Bir dosyanın SHA-256 hash'ini küçük harf hex olarak hesaplar
    private func computeSHA256(for url: URL) -> String? {
        guard let stream = InputStream(url: url) else { return nil }
        stream.open()
        defer { stream.close() }

        var hasher = SHA256()
        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 { return nil }
            if bytesRead == 0 { break }
            hasher.update(bufferPointer: UnsafeRawBufferPointer(start: buffer, count: bytesRead))
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
