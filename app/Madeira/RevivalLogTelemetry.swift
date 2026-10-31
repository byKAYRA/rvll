import Foundation
import UIKit

// MARK: - RevivalLogTelemetry
/// Hata ve teşhis loglarını toplayıp anonim buluta (filebin.net) yükleyen ve iOS paylaşım sayfası sağlayan servis.
final class RevivalLogTelemetry {
    static let shared = RevivalLogTelemetry()

    private init() {}

    let binId = "revival-logs-kayra"
    private let baseURL = "https://filebin.net"

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Logları toplayıp anonim buluta (filebin.net) yükler
    func uploadLogs(triggerReason: String = "manual", completion: ((Bool, String) -> Void)? = nil) {
        Task {
            let files = self.gatherDiagnostics(triggerReason: triggerReason)
            let (success, message) = await self.uploadToFilebin(files: files)
            DispatchQueue.main.async {
                completion?(success, message)
            }
        }
    }

    /// Dosyaları filebin.net üzerine yükler
    private func uploadToFilebin(files: [String: String]) async -> (Bool, String) {
        guard !files.isEmpty else {
            return (false, "Yüklenecek log dosyası bulunamadı.")
        }

        var uploadedCount = 0
        var lastError = ""

        for (filename, content) in files {
            guard let fileURL = URL(string: "\(baseURL)/\(binId)/\(filename)") else { continue }

            var request = URLRequest(url: fileURL)
            request.httpMethod = "POST"
            request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("RevivalMobile-iOS", forHTTPHeaderField: "User-Agent")
            request.httpBody = content.data(using: .utf8)
            request.timeoutInterval = 15.0

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    uploadedCount += 1
                } else {
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    lastError = "HTTP \(code)"
                }
            } catch {
                lastError = error.localizedDescription
            }
        }

        if uploadedCount > 0 {
            return (true, "Loglar buluta yüklendi (\(uploadedCount) dosya): filebin.net/\(binId)")
        } else {
            return (false, "Log yükleme başarısız oldu: \(lastError)")
        }
    }

    /// Tüm logları tek bir metin dosyasında birleştirir ve dosya URL'si döndürür (Paylaşım / AirDrop için)
    func exportCombinedDiagnostics(triggerReason: String = "export") -> URL? {
        let files = gatherDiagnostics(triggerReason: triggerReason)
        var combined = "========================================================\n"
        combined += "  REVIVAL MOBILE TEŞHİS RAPORU\n"
        combined += "  Tarih: \(ISO8601DateFormatter().string(from: Date()))\n"
        combined += "  Filebin: \(baseURL)/\(binId)\n"
        combined += "========================================================\n\n"

        for (filename, content) in files.sorted(by: { $0.key < $1.key }) {
            combined += "--------------------------------------------------------\n"
            combined += "  DOSYA: \(filename)\n"
            combined += "--------------------------------------------------------\n"
            combined += content + "\n\n"
        }

        let exportURL = documentsDirectory.appendingPathComponent("revival_diagnostic_report.txt")
        do {
            try combined.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
        } catch {
            print("[RevivalLog] Rapor kaydedilemedi: \(error)")
            return nil
        }
    }

    /// Cihaz durumu, log dosyaları ve dizin haritasını toplar
    func gatherDiagnostics(triggerReason: String) -> [String: String] {
        var files: [String: String] = [:]

        // 1. Sistem ve Çevre Özeti
        let device = UIDevice.current
        var systemInfo = """
        Revival Mobile Teşhis Raporu
        Tarih: \(ISO8601DateFormatter().string(from: Date()))
        Tetikleyici: \(triggerReason)
        Cihaz: \(device.model)
        Sistem: \(device.systemName) \(device.systemVersion)
        JIT Durumu: ready=\(StikJITHelper.ready ? "EVET" : "HAYIR"), attached=\(isDebuggerAttached() ? "EVET" : "HAYIR"), builtin=\(MadeiraBuiltInJIT.isAvailable ? "VAR" : "YOK")
        Wineserver Durumu: running=\(wineserver_is_running() != 0 ? "EVET" : "HAYIR"), ready=\(wineserver_is_ready() != 0 ? "EVET" : "HAYIR")
        Wine Process: running=\(wine_process_is_running() != 0 ? "EVET" : "HAYIR")
        """

        // Dizin listesini ekle
        let winePrefixURL = documentsDirectory.appendingPathComponent("wine")
        systemInfo += "\n\n--- Wine Prefix İçeriği ---\n"
        systemInfo += listDirectory(at: winePrefixURL, depth: 2)

        let revivalGameURL = winePrefixURL.appendingPathComponent("drive_c/Revival")
        systemInfo += "\n\n--- C:\\Revival İçeriği ---\n"
        systemInfo += listDirectory(at: revivalGameURL, depth: 1)

        files["00_system_info.txt"] = systemInfo

        // 2. Madeira Motor Logu (madeira-log.txt)
        let madeiraLogURL = documentsDirectory.appendingPathComponent("madeira-log.txt")
        if let content = readLastLines(of: madeiraLogURL, maxLines: 2000) {
            files["madeira-log.txt"] = content
        }

        // 3. Revival Launcher Logu (launcher.log)
        let primaryLauncherLog = winePrefixURL.appendingPathComponent("drive_c/users/mobile/AppData/Roaming/Revival/logs/launcher.log")
        let fallbackLauncherLog = revivalGameURL.appendingPathComponent("launcher.log")
        if let content = readLastLines(of: primaryLauncherLog, maxLines: 1500) {
            files["launcher.log"] = content
        } else if let content = readLastLines(of: fallbackLauncherLog, maxLines: 1500) {
            files["launcher.log"] = content
        }

        // 4. Ncrypt Shim Logu (ncrypt-shim.log)
        let shimLogURL = winePrefixURL.appendingPathComponent("drive_c/users/mobile/AppData/Roaming/Revival/logs/ncrypt-shim.log")
        if let content = readLastLines(of: shimLogURL, maxLines: 500) {
            files["ncrypt-shim.log"] = content
        }

        return files
    }

    private func listDirectory(at url: URL, depth: Int) -> String {
        guard FileManager.default.fileExists(atPath: url.path) else { return "\(url.lastPathComponent) (Mevcut değil)\n" }
        guard depth >= 0 else { return "" }

        var result = ""
        if let items = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
            for item in items.prefix(30) {
                let subURL = url.appendingPathComponent(item)
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: subURL.path, isDirectory: &isDir)
                if isDir.boolValue {
                    result += "[DIR]  \(item)/\n"
                    if depth > 0 {
                        let subListing = listDirectory(at: subURL, depth: depth - 1)
                        for line in subListing.components(separatedBy: .newlines) where !line.isEmpty {
                            result += "       \(line)\n"
                        }
                    }
                } else {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: subURL.path)
                    let size = (attrs?[.size] as? Int64) ?? 0
                    result += "[FILE] \(item) (\(size) bytes)\n"
                }
            }
        }
        return result.isEmpty ? "(Boş dizin)\n" : result
    }

    private func readLastLines(of url: URL, maxLines: Int) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) ?? String(contentsOf: url, encoding: .isoLatin1) else {
            return nil
        }
        let lines = text.components(separatedBy: .newlines)
        if lines.count <= maxLines {
            return text
        }
        return lines.suffix(maxLines).joined(separator: "\n")
    }
}
