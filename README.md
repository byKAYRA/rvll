# Revival Mobile (rvll) — Goley TR iOS Client

<p align="center">
  <img src="docs/assets/banner.png" alt="Revival Mobile Banner" width="100%">
</p>

<p align="center">
  <a href="https://github.com/byKAYRA/rvll/releases"><img src="https://img.shields.io/github/v/release/byKAYRA/rvll?label=Release&style=for-the-badge&color=brightgreen" alt="Latest release"></a>
  &nbsp;&nbsp;&nbsp;
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--or--later-yellow?style=for-the-badge" alt="License: GPL-3.0-or-later"></a>
</p>

**Revival Mobile**, PC tabanlı **Revival (Goley TR)** oyununu iPhone ve iPad cihazlarda jailbreak gerektirmeden, yerel performans ve dokunmatik futbol kontrolleriyle çalıştırmak için özelleştirilmiş özel bir istemcidir.

---

## ⚽ Özellikler ve Değişiklikler (Madeira'dan Farkları)

Upstream Madeira projesi genel bir PC/Steam/Epic kütüphane emülatörüyken, **Revival Mobile (rvll)** doğrudan tek bir amaca odaklanacak şekilde yeniden tasarlandı:

1. **Doğrudan Oyuna Geçiş (Direct-to-Game)**:
   - Steam, Epic Games ve genel vitrin menüleri kaldırılarak uygulama açılır açılmaz doğrudan Revival yükleme ekranı ve ardından `revival_launcher.exe` başlatılır.
   - Launcher arka planda veya ön planda güncellemeleri çekip `BinaryTrU.exe`'yi tetikler.

2. **Qt 6 / DXMT SwapChain Düzeltmesi (Beyaz Ekran Çözümü)**:
   - Qt 6.5+ tabanlı Revival launcher'ının `DXGI_SWAP_EFFECT_FLIP_DISCARD` (4) çağrısı DXMT tarafından desteklenmediği için oluşan `0x80004001 E_NOTIMPL` beyaz ekran hatası giderildi.
   - `QT_D3D_NO_FLIP=1` ve `QT_D3D_FLIP_DISCARD=0` zorlamasıyla Metal üzerinde kusursuz DirectX 11 render'ı sağlandı.

3. **Özel Goley Futbol Dokunmatik Şeması (`GoleyControlPreset`)**:
   - Sol tarafta dinamik analog joystick (Yönlendirme / Koşu).
   - Sağ tarafta tam futbol aksiyon butonları:
     - **S** (Kısa Pas / Pres)
     - **D** (Şut / Kayarak Müdahale)
     - **A** (Yüksek Orta / Kaleci Açma)
     - **W** (Ara Pası / İkili Pres)
     - **E** (Hızlı Koşu / Sprint)
     - **Q** (Futbolcu Değiştirme / Ver-Kaç)
     - **C** (Plase / Özel Çalım)
     - **Z** (Taktik Değiştirme)

4. **SSL / Sertifika ve DLL Shim Entegrasyonu**:
   - Revival sunucu iletişimleri ve TLS el sıkışmaları için `cacert.pem` doğrudan bundle içine gömüldü.
   - `winspool.drv`, `ncrypt.dll` ve `dinput8.dll` shim'leri otomatik olarak yapılandırıldı.

---

## 🛠️ Mimari Katmanlar

| Katman | İşlevi |
|---|---|
| **FEX-Emu** | x86 / x86_64 oyun kodlarını gerçek zamanlı olarak ARM64 talimatlarına çevirir. |
| **Wine 11 (ARM64EC)** | Windows API ortamını sağlar; Wine'ın kendisi yerel ARM64 hızında çalışır. |
| **DXMT (DirectX to Metal)** | Direct3D 9, 10 ve 11 grafik çağrılarını doğrudan Apple Metal API'sine dönüştürür. |
| **Revival Touch Overlay** | Sanal joystick ve tuş girdilerini Windows Sanal Klavye ve DirectInput'a iletir. |

---

## 🚀 Derleme Yolları (Build Pathways)

### 1. GitHub Actions ile Otomatik IPA Derleme (Mac Gerektirmez)
GitHub Actions workflow'u projenin `.github/workflows/build.yml` dosyasında hazırdır:
1. `https://github.com/byKAYRA/rvll` reposunda **Actions** sekmesine gidin.
2. Sol menüden **Build IPA** iş akışını seçin.
3. **Run workflow** butonuna tıklayarak derlemeyi başlatın.
4. İşlem tamamlandığında **Artifacts** bölümünden `Revival-Mobile-IPA` zip dosyasını indirin. İçinden `Revival.ipa` çıkacaktır.

### 2. Mac Üzerinde Xcode ile Yerel Derleme
Bir Mac bilgisayarınız varsa terminal üzerinden:
```bash
git clone --recursive https://github.com/byKAYRA/rvll.git
cd rvll
tools/build-ipa.sh
```
Derlenen paket `dist/Revival.ipa` konumunda hazır olur.

---

## 📲 Cihaza Yükleme (Sideloading)

İndirdiğiniz `Revival.ipa` dosyasını iPhone/iPad'inize yüklemek için aşağıdaki araçlardan birini kullanabilirsiniz:

- **SideStore / AltStore (Önerilen)**:
  - Bilgisayar üzerinden AltServer veya doğrudan cihazdan SideStore kullanarak kendi Apple ID'nizle ücretsiz imzalayıp kurabilirsiniz.
  - JIT (Just-In-Time) desteği için SideStore içerisinden "Enable JIT" seçeneği kullanılabilir.
- **Sideloadly (Windows & Mac)**:
  - Cihazı USB ile bağlayın, Sideloadly programında `Revival.ipa`'yı seçin ve "Start"a basın.
- **TrollStore** (iOS 14.0 - 16.6.1 / 17.0):
  - 7 günlük süre sınırı ve JIT kısıtı olmadan doğrudan yükleyebilirsiniz.

---

## 📜 Lisans
Bu proje [GNU General Public License v3.0](LICENSE) altında lisanslanmıştır.
