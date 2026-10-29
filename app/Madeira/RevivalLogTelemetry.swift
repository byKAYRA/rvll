import Foundation
import UIKit

// MARK: - RevivalLogTelemetry
/// Hata ve teşhis loglarını toplayıp GitHub Gist veya webhook'a otomatik ileten servis.
final class RevivalLogTelemetry {
    static let shared = RevivalLogTelemetry()

    private init() {}

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Logları toplayıp uzaktaki merkeze yükler
    func uploadLogs(triggerReason: String = "manual", completion: ((Bool, String) -> Void)? = nil) {
        Task {
            let logPayload = self.gatherDiagnostics(triggerReason: triggerReason)
            let success = await self.sendToGitHubGist(payload: logPayload)
            DispatchQueue.main.async {
                if success {
                    completion?(true, "Loglar GitHub Gist'e başarıyla yüklendi.")
                } else {
                    completion?(false, "Log yüklemesi tamamlanamadı.")
                }
            }
        }
    }

    /// Tüm log dosyalarını ve cihaz durumunu birleştirir
    func gatherDiagnostics(triggerReason: String) -> [String: String] {
        var files: [String: String] = [:]

        // 1. Cihaz ve Oturum Özeti
        let device = UIDevice.current
        let systemInfo = """
        Revival Mobile Teşhis Raporu
        Tarih: \(ISO8601DateFormatter().string(from: Date()))
        Tetikleyici: \(triggerReason)
        Cihaz Modeli: \(device.model)
        Sistem: \(device.systemName) \(device.systemVersion)
        """
        files["00_system_info.txt"] = systemInfo

        // 2. Madeira Motor Logu (madeira-log.txt)
        let madeiraLogURL = documentsDirectory.appendingPathComponent("madeira-log.txt")
        if let content = readLastLines(of: madeiraLogURL, maxLines: 1500) {
            files["madeira-log.txt"] = content
        }

        // 3. Revival Launcher Logu (launcher.log)
        let launcherLogURL = documentsDirectory.appendingPathComponent("wine/drive_c/users/mobile/AppData/Roaming/Revival/logs/launcher.log")
        if let content = readLastLines(of: launcherLogURL, maxLines: 1000) {
            files["launcher.log"] = content
        }

        // 4. Ncrypt Shim Logu (ncrypt-shim.log - varsa)
        let shimLogURL = documentsDirectory.appendingPathComponent("wine/drive_c/users/mobile/AppData/Roaming/Revival/logs/ncrypt-shim.log")
        if let content = readLastLines(of: shimLogURL, maxLines: 500) {
            files["ncrypt-shim.log"] = content
        }

        return files
    }

    /// Logları GitHub Gist API'sine JSON olarak gönderir
    private func sendToGitHubGist(payload: [String: String]) async -> Bool {
        guard let apiURL = URL(string: "https://api.github.com/gists") else { return false }

        var gistFiles: [String: [String: String]] = [:]
        for (filename, text) in payload {
            gistFiles[filename] = ["content": text]
        }

        let bodyDict: [String: Any] = [
            "description": "Revival Mobile iOS Otomatik Teşhis Logu (\(Date().description))",
            "public": false,
            "files": gistFiles
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict, options: []) else {
            return false
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("RevivalMobile-iOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = bodyData
        request.timeoutInterval = 10.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let htmlUrl = json["html_url"] as? String {
                    print("[RevivalLog] Loglar GitHub Gist'e yüklendi: \(htmlUrl)")
                }
                return true
            } else {
                print("[RevivalLog] Gist API yanıt kodu: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                return false
            }
        } catch {
            print("[RevivalLog] Gist yükleme hatası: \(error.localizedDescription)")
            return false
        }
    }

    /// Büyük log dosyalarının sadece son N satırını okur (bellek koruması)
    private func readLastLines(of url: URL, maxLines: Int) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            // Latin1 fallback
            guard let latin = try? String(contentsOf: url, encoding: .isoLatin1) else { return nil }
            return latin
        }

        let lines = text.components(separatedBy: .newlines)
        if lines.count <= maxLines {
            return text
        }
        let tail = lines.suffix(maxLines)
        return tail.joined(separator: "\n")
    }
}
