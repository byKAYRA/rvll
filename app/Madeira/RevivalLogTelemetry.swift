import Foundation
import UIKit

// MARK: - RevivalLogTelemetry
/// Hata ve teşhis loglarını toplayıp doğrudan Discord kanalına gönderen ve iOS paylaşım sayfası sağlayan telemetri servisi.
final class RevivalLogTelemetry {
    static let shared = RevivalLogTelemetry()

    private init() {}

    /// Varsayılan Discord Webhook URL'si
    let defaultDiscordWebhookURL = "https://discord.com/api/webhooks/1566121518344306779/n7Tvh_z_WlnPEo_oweLEg-o4ITZkgmCyeC4kJA9F7WxbknJ9snt2zEXx2ZKmccjOVdtm"

    /// Discord Webhook URL (Varsayılan olarak tanımlıdır, istenirse ayarlanabilir)
    var discordWebhookURL: String {
        get {
            let saved = UserDefaults.standard.string(forKey: "revivalDiscordWebhookURL") ?? ""
            return saved.isEmpty ? defaultDiscordWebhookURL : saved
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "revivalDiscordWebhookURL")
        }
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Discord Üzerinden Log Gönderme
    /// Uygulama klasörlerindeki TÜM log dosyalarını Discord kanalına zengin embed ve ekler (attachments) olarak gönderir.
    func uploadLogs(triggerReason: String = "manual", completion: ((Bool, String) -> Void)? = nil) {
        guard let targetURL = URL(string: self.discordWebhookURL) else {
            completion?(false, "Geçersiz Discord Webhook URL'si.")
            return
        }

        Task {
            let logFiles = self.gatherAllLogFiles(triggerReason: triggerReason)
            guard !logFiles.isEmpty else {
                DispatchQueue.main.async { completion?(false, "Gönderilecek log dosyası bulunamadı.") }
                return
            }

            let (success, message) = await self.sendMultipartToDiscord(url: targetURL, files: logFiles, triggerReason: triggerReason)
            DispatchQueue.main.async {
                completion?(success, message)
            }
        }
    }

    /// Discord Webhook API'sine multipart/form-data ile çoklu dosya ve embed gönderir
    private func sendMultipartToDiscord(url: URL, files: [String: String], triggerReason: String) async -> (Bool, String) {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("RevivalMobile-Telemetry/2.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30.0

        let device = UIDevice.current
        let dateStr = ISO8601DateFormatter().string(from: Date())

        let summaryText = """
        ```
        [revival-log] \(dateStr)
        device: \(device.model) | \(device.systemName) \(device.systemVersion)
        jit: \(StikJITHelper.ready ? "ready" : "none") | wineserver: \(wineserver_is_running() != 0 ? "running" : "stopped") | wine: \(wine_process_is_running() != 0 ? "running" : "stopped")
        trigger: \(triggerReason) | files: \(files.count)
        ```
        """

        let payloadJsonDict: [String: Any] = [
            "content": summaryText
        ]

        guard let payloadJsonData = try? JSONSerialization.data(withJSONObject: payloadJsonDict, options: []) else {
            return (false, "JSON oluşturulamadı.")
        }

        var body = Data()

        // 1. payload_json part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"payload_json\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json\r\n\r\n".data(using: .utf8)!)
        body.append(payloadJsonData)
        body.append("\r\n".data(using: .utf8)!)

        // 2. Dosya ekleri (files[0], files[1], ...)
        var fileIndex = 0
        for (filename, textContent) in files.sorted(by: { $0.key < $1.key }) {
            guard fileIndex < 10 else { break } // Discord mesaj başı max 10 ek kabul eder
            let fileData = textContent.data(using: .utf8) ?? Data()

            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"files[\(fileIndex)]\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: text/plain; charset=utf-8\r\n\r\n".data(using: .utf8)!)
            body.append(fileData)
            body.append("\r\n".data(using: .utf8)!)

            fileIndex += 1
        }

        // Kapanış boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                return (true, "Loglar Discord kanalına başarıyla gönderildi! (\(fileIndex) dosya)")
            } else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return (false, "Discord yanıt kodu: HTTP \(code)")
            }
        } catch {
            return (false, "Discord bağlantı hatası: \(error.localizedDescription)")
        }
    }

    // MARK: - Paylaşım Raporu Oluşturma (AirDrop / Dosyalar)
    /// Tüm logları tek bir metin dosyasında birleştirir ve dosya URL'si döndürür
    func exportCombinedDiagnostics(triggerReason: String = "export") -> URL? {
        let files = gatherAllLogFiles(triggerReason: triggerReason)
        var combined = "========================================================\n"
        combined += "  REVIVAL MOBILE TEŞHİS RAPORU\n"
        combined += "  Tarih: \(ISO8601DateFormatter().string(from: Date()))\n"
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

    // MARK: - Klasörlerdeki TÜM Log Dosyalarını Tarama ve Toplama
    /// Uygulama klasörlerindeki (.log ve .txt) tüm logları dinamik olarak bulur
    func gatherAllLogFiles(triggerReason: String) -> [String: String] {
        var files: [String: String] = [:]

        // 1. Sistem ve Çevre Durumu (00_system_info.txt)
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

        let winePrefixURL = documentsDirectory.appendingPathComponent("wine")
        systemInfo += "\n\n--- Wine Prefix İçeriği ---\n"
        systemInfo += listDirectory(at: winePrefixURL, depth: 2)

        let revivalGameURL = winePrefixURL.appendingPathComponent("drive_c/Revival")
        systemInfo += "\n\n--- C:\\Revival İçeriği ---\n"
        systemInfo += listDirectory(at: revivalGameURL, depth: 1)

        files["00_system_info.txt"] = systemInfo

        // 2. Documents ve Wine altındaki tüm loglar
        let searchDirectories = [
            documentsDirectory,
            winePrefixURL.appendingPathComponent("drive_c/users/mobile/AppData/Roaming/Revival/logs"),
            winePrefixURL.appendingPathComponent("drive_c/Revival"),
            winePrefixURL.appendingPathComponent("drive_c")
        ]

        for dir in searchDirectories {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            if let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    let name = fileURL.lastPathComponent
                    if ext == "log" || ext == "txt" || name.contains("log") {
                        if files[name] == nil {
                            if let content = readLastLines(of: fileURL, maxLines: 2500) {
                                files[name] = content
                            }
                        }
                    }
                }
            }
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
