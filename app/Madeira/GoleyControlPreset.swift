import Foundation
import SwiftUI
import UIKit

// MARK: - Goley TR / Revival Mobile Futbol Kontrol Şeması
// Sol: 360° Sanal Analog Joystick (Yön Tuşları: Yukarı, Aşağı, Sol, Sağ)
// Sağ Elmas Düzeni:
//   - S: Kısa Pas / Müdahale (Yeşil)
//   - D: Şut / Ayak Koyma / Pres (Kırmızı)
//   - A: Yüksek Orta / Kayarak Müdahale (Mavi)
//   - W: Ara Pası / Kaleci Çıkarma (Sarı)
//   - E: Hızlı Koşu / Depar (Turuncu)
//   - Q: Adam Değiştirme / Taktik (Mor)
//   - C: Çalım / Özel Yetenek
//   - Z: Taktiksel Diziliş
//   - ESC & ENTER: Menü & Sohbet

extension ControlPresetLayout {
    static let goleyID = "builtin.goley"
    static let goleyName = "Goley Futbol (Revival)"

    static func goley(for screen: ControlPresetScreen) -> [TouchControl] {
        let s = screen.landscape
        let W = s.width, H = s.height
        guard W > 0, H > 0 else { return [] }
        let k = min(max(H / 400, 1.0), 1.3)
        let (L, R, T, B) = margins(s)
        var out: [TouchControl] = []

        func addKey(_ vk: Int32, _ scale: Double, _ x: Double, _ y: Double) {
            var c = TouchControl()
            c.action = .key(vk)
            c.scale = scale
            c.nx = x / W
            c.ny = y / H
            out.append(c)
        }

        func d(_ scale: Double) -> Double { baseDiameter * scale }

        // 1. SOL SANAL ANALOG JOYSTICK (Goley Yön Tuşları: Ok Tuşları)
        let stickScale = 1.55 * k
        let stick = d(stickScale)
        let stickY = H - B - 16 * k - stick / 2
        let lStickX = L + 85 * k
        
        var stickControl = TouchControl()
        stickControl.action = .joystickArrows
        stickControl.scale = stickScale
        stickControl.nx = lStickX / W
        stickControl.ny = stickY / H
        out.append(stickControl)

        // 2. SAĞ AKSİYON ELMASI (S, D, A, W)
        let faceScale = 0.95 * k
        let face = d(faceScale)
        let o = face / 2 + 26 * k
        let cx = W - R - 92 * k
        let cy = H - B - 26 * k - o - face / 2

        // S (Kısa Pas / Müdahale) - Alt
        addKey(0x53, 1.15 * faceScale, cx, cy + o)
        
        // D (Şut / Pres) - Sağ
        addKey(0x44, 1.15 * faceScale, cx + o, cy)
        
        // A (Orta / Kayma) - Sol
        addKey(0x41, 1.05 * faceScale, cx - o, cy)
        
        // W (Ara Pası / Kaleci) - Üst
        addKey(0x57, 1.05 * faceScale, cx, cy - o)

        // 3. E TUŞU (HIZLI KOŞU / DEPAR) - Sağ Üst Omuz / Tetik
        let sprintScale = 1.10 * k
        addKey(0x45, sprintScale, cx + o * 0.9, cy - o * 1.5)

        // 4. Q TUŞU (ADAM DEĞİŞTİRME) - Sol Üst Omuz
        let switchScale = 0.90 * k
        addKey(0x51, switchScale, lStickX, stickY - stick / 2 - 28 * k)

        // 5. C (Çalım / Beceri) & Z (Taktik) TUŞLARI
        let skillScale = 0.75 * k
        addKey(0x43, skillScale, cx - o * 0.95, cy + o * 1.35) // C (Çalım)
        addKey(0x5A, skillScale, cx - o * 1.45, cy + o * 0.5)  // Z (Taktik)

        // 6. ÜST BAR: ESC & ENTER
        let barScale = 0.72 * k
        addKey(0x1B, barScale, W / 2 - 45 * k, T + 20 * k) // ESC
        addKey(0x0D, barScale, W / 2 + 45 * k, T + 20 * k) // ENTER

        return out
    }
}
