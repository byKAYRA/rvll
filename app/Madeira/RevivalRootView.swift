import Foundation
import SwiftUI
import UIKit

// MARK: - Revival Mobile (Goley TR) Ana Görünümü & Başlatıcı
struct RevivalRootView: View {
    @ObservedObject private var touchModel = TouchControlsModel.shared
    @ObservedObject private var syncEngine = RevivalSyncEngine.shared

    @State private var isGameRunning = false
    @State private var isStartingWine = false
    @State private var statusMessage = "Revival hazır."
    @State private var showControls = true
    @State private var wineStarted = false
    @State private var isUploadingLogs = false
    @State private var toastMessage: String? = nil
    @State private var showJITSheet = false
    @State private var isJITReady = StikJITHelper.ready
    @State private var showLogMenu = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false
    @State private var showDiscordWebhookAlert = false
    @State private var inputWebhookURL = RevivalLogTelemetry.shared.discordWebhookURL
    @State private var wineCrashMessage: String? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Zemin Siyah Arka Plan
                Color.black.ignoresSafeArea()

                // 2. Metal Render Katmanı (Wine / Windows Explorer Desktop / DXMT)
                MadeiraMetalView()
                    .ignoresSafeArea()

                // 3. Dokunmatik Futbol Kontrolleri (Goley Kontrolleri)
                if showControls && isGameRunning {
                    TouchControlsOverlay()
                        .ignoresSafeArea()
                }

                // 4. Revival Başlatıcı & Kontrol Paneli (Oyun başlamadan önce veya çökerse görünür)
                if !isGameRunning {
                    launcherDashboard(geo: geo)
                        .transition(.opacity)
                }

                // 5. Minimalist Üst Kontrol Barı (Oyun ekranındayken veya menüdeyken)
                topControlBar
            }
            .onAppear {
                // Başlangıçta Metal katmanını gizle ki başlatıcı paneli net görünsün
                MetalHostView.shared.isHidden = true
                isJITReady = StikJITHelper.ready

                // Goley Kontrol düzenini hafızaya hazırla
                let screen = ControlPresetScreen(
                    width: geo.size.width,
                    height: geo.size.height,
                    left: 16, right: 16, top: 8, bottom: 8
                )
                ControlPresetsModel.shared.load(ControlPresetLayout.goleyID, screen: screen, reason: "revival-init")
            }
            // Canlı JIT Durumu Yoklayıcısı (Her 1.2 saniyede kontrol eder)
            .task {
                while !Task.isCancelled {
                    let ready = StikJITHelper.ready
                    if ready != isJITReady {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isJITReady = ready
                        }
                        if ready {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            showToast("⚡ JIT Algılandı ve Hazır!")
                        }
                    }
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                isJITReady = StikJITHelper.ready
            }
            .sheet(isPresented: $showJITSheet, onDismiss: {
                isJITReady = StikJITHelper.ready
            }) {
                JITSetupView()
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = shareURL {
                    RevivalActivityView(activityItems: [url])
                }
            }
            .confirmationDialog("Teşhis ve Log Seçenekleri", isPresented: $showLogMenu, titleVisibility: .visible) {
                Button("🎮 Discord Kanalına Gönder (#log)") {
                    uploadLogsToDiscord()
                }
                Button("📤 Log Dosyasını Paylaş / Kaydet (AirDrop / Dosyalar)") {
                    exportAndShareLogs()
                }
                Button("⚙️ Discord Webhook URL Değiştir") {
                    inputWebhookURL = RevivalLogTelemetry.shared.discordWebhookURL
                    showDiscordWebhookAlert = true
                }
                Button("İptal", role: .cancel) {}
            }
            .alert("Discord Webhook Ayarı", isPresented: $showDiscordWebhookAlert) {
                TextField("https://discord.com/api/webhooks/...", text: $inputWebhookURL)
                Button("Kaydet ve Gönder") {
                    RevivalLogTelemetry.shared.discordWebhookURL = inputWebhookURL
                    uploadLogsToDiscord()
                }
                Button("Yalnızca Kaydet") {
                    RevivalLogTelemetry.shared.discordWebhookURL = inputWebhookURL
                    showToast("Discord Webhook URL kaydedildi.")
                }
                Button("İptal", role: .cancel) {}
            } message: {
                Text("Discord kanalınızın Webhook URL'sini yapıştırın. Uygulamadaki tüm log dosyaları kanala otomatik yüklenecektir.")
            }
        }
    }

    // MARK: - Başlatıcı & Dashboard Arayüzü
    @ViewBuilder
    private func launcherDashboard(geo: GeometryProxy) -> some View {
        ZStack {
            // Şık koyu zemin ve radyal degrade
            Color(red: 0.04, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            RadialGradient(
                colors: [Color.green.opacity(0.12), Color.cyan.opacity(0.06), Color.clear],
                center: .top,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer().frame(height: 30)

                // 1. Revival & Goley Logo
                VStack(spacing: 6) {
                    Text("REVIVAL")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.mint, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .green.opacity(0.6), radius: 14, x: 0, y: 4)

                    Text("GOLEY MOBILE • WINE EDITION")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(5)
                        .foregroundStyle(.white.opacity(0.75))
                }

                // 2. Varsa Hata / Kapanma Bildirimi Kartı
                if let errorMsg = wineCrashMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Oyun Oturumu Sonlandı")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                            Text(errorMsg)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(.white.opacity(0.85))
                        }

                        Spacer()

                        Button {
                            uploadLogsToDiscord()
                        } label: {
                            Text("Log Gönder")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.3))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(14)
                    .background(Color.red.opacity(0.2))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: 520)
                    .padding(.horizontal, 20)
                }

                // 3. JIT ve Sistem Durum Kartı
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(isJITReady ? Color.green.opacity(0.2) : Color.yellow.opacity(0.18))
                                .frame(width: 50, height: 50)

                            Image(systemName: isJITReady ? "bolt.shield.fill" : "bolt.slash.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(isJITReady ? Color.green : Color.yellow)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(isJITReady ? "JIT Durumu: Aktif" : "JIT Durumu: Bekleniyor")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)

                                Spacer()

                                Text(isJITReady ? "HAZIR" : "GEREKLİ")
                                    .font(.system(size: 10, weight: .heavy))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(isJITReady ? Color.green.opacity(0.3) : Color.yellow.opacity(0.25))
                                    .foregroundStyle(isJITReady ? Color.green : Color.yellow)
                                    .clipShape(Capsule())
                            }

                            Text(isJITReady
                                 ? "Windows ikili kod derleyicisi ve hafıza havuzu hazır. Oyunu başlatabilirsiniz."
                                 : "iOS kısıtlaması nedeniyle oyunun çalışması için JIT gereklidir. JIT açılmadan oyun başlatılırsa sistem uygulamayı kapatır.")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(3)
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isJITReady ? Color.green.opacity(0.4) : Color.yellow.opacity(0.3), lineWidth: 1)
                    )

                    // 4. Ana Eylem Butonu (JIT Etkinleştir VEYA Oyunu Başlat)
                    if isStartingWine {
                        VStack(spacing: 12) {
                            if syncEngine.isSyncing {
                                ProgressView(value: max(0.05, syncEngine.progressFraction))
                                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                    .frame(maxWidth: 320)
                                Text(syncEngine.progressText)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                    .scaleEffect(1.2)
                                Text(statusMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .padding(.vertical, 16)
                    } else if isJITReady {
                        // JIT Hazır -> Büyük Başlatma Butonu
                        Button {
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            startRevivalSession(geo: geo)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 24, weight: .bold))
                                Text("OYUNU BAŞLAT")
                                    .font(.system(size: 17, weight: .black, design: .rounded))
                                    .tracking(2)
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.95, blue: 0.4), Color.green],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.green.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                    } else {
                        // JIT Henüz Açık Değil -> JIT Etkinleştirme Butonları
                        VStack(spacing: 10) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                handleEnableJIT()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 20, weight: .bold))
                                    Text(StikJITHelper.isAvailable ? "STIKDEBUG İLE JIT'İ AÇ" : "JIT'İ ETKİNLEŞTİR")
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .tracking(1)
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [Color.yellow, Color.orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: Color.orange.opacity(0.35), radius: 8, x: 0, y: 4)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    showJITSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "gearshape.fill")
                                        Text("JIT Eşleştirme / Menü")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                Button {
                                    isJITReady = StikJITHelper.ready
                                    showToast(isJITReady ? "✅ JIT Hazır!" : "⚠️ JIT henüz algılanmadı.")
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.clockwise")
                                        Text("Durumu Kontrol Et")
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 20)

                Spacer()

                // 5. Alt Yardımcı & Teşhis Çubuğu
                HStack(spacing: 12) {
                    Button {
                        uploadLogsToDiscord()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.exclamationmark.bubble.right.fill")
                            Text("Discord'a Log Gönder")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }

                    Button {
                        exportAndShareLogs()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Logları Paylaş")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }

                    Button {
                        Task {
                            await syncEngine.synchronize()
                            showToast("GitHub canlı senkronizasyon tamamlandı.")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Dosyaları Eşitle")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Minimalist Üst Kontrol Barı
    private var topControlBar: some View {
        VStack {
            HStack(spacing: 10) {
                // Dokunmatik Kontrolleri Aç/Kapat (Yalnızca oyun çalışırken anlamlı)
                if isGameRunning {
                    Button {
                        showControls.toggle()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: showControls ? "gamecontroller.fill" : "gamecontroller")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(showControls ? 0.95 : 0.4))
                            .padding(9)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    // Sanal Klavye Aç/Kapat
                    Button {
                        MetalBackedView.toggleKeyboard()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(9)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                // JIT Rozeti (⚡)
                Button {
                    showJITSheet = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isJITReady ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isJITReady ? "JIT" : "JIT!")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(isJITReady ? .green : .yellow)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                // Teşhis / Log Menüsü
                Button {
                    showLogMenu = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Image(systemName: isUploadingLogs ? "arrow.triangle.2.circlepath" : "ladybug.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isUploadingLogs ? .yellow : .white.opacity(0.9))
                        .padding(9)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                // Çıkış / Kapat
                Button {
                    RevivalLogTelemetry.shared.uploadLogs(triggerReason: "exit-button")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        exit(0)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(9)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Toast / Bildirim
            if let toast = toastMessage {
                Text(toast)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.85))
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
    }

    // MARK: - Eylemler ve JIT Yönetimi
    private func handleEnableJIT() {
        if StikJITHelper.isAvailable {
            statusMessage = "StikDebug açılıyor..."
            showToast("StikDebug açılıyor...")
            StikJITHelper.enableJIT { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.isJITReady = true
                        self.showToast("✅ JIT başarıyla etkinleştirildi!")
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    case .failure(let err):
                        self.showToast("JIT: \(err.localizedDescription)")
                        self.showJITSheet = true
                    }
                }
            }
        } else {
            showJITSheet = true
        }
    }

    private func uploadLogsToDiscord() {
        isUploadingLogs = true
        showToast("Tüm loglar taranıyor ve Discord kanalına yükleniyor...")
        RevivalLogTelemetry.shared.uploadToDiscord(triggerReason: "user-button") { success, msg in
            isUploadingLogs = false
            showToast(msg)
        }
    }

    private func exportAndShareLogs() {
        if let url = RevivalLogTelemetry.shared.exportCombinedDiagnostics(triggerReason: "share-sheet") {
            shareURL = url
            showShareSheet = true
        } else {
            showToast("Log raporu oluşturulamadı.")
        }
    }

    private func showToast(_ text: String) {
        withAnimation {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            withAnimation {
                if toastMessage == text {
                    toastMessage = nil
                }
            }
        }
    }

    // MARK: - Güvenli Oyun Oturumu Başlatma
    private func startRevivalSession(geo: GeometryProxy) {
        guard !isStartingWine && !isGameRunning else { return }

        // JIT GÜVENLİK KONTROLÜ: JIT olmadan Wine ASLA başlatılmaz!
        guard StikJITHelper.ready else {
            showToast("⚠️ JIT henüz aktif değil! Lütfen önce JIT'i etkinleştirin.")
            UIImpactFeedbackGenerator(style: .error).impactOccurred()
            return
        }

        isStartingWine = true
        wineStarted = true
        wineCrashMessage = nil

        Task {
            // 1. GitHub Güncellemelerini Denetle
            statusMessage = "Güncellemeler denetleniyor..."
            await syncEngine.synchronize()

            statusMessage = "JIT hafıza havuzu tahsis ediliyor..."

            DispatchQueue.global(qos: .userInteractive).async {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let prefix = docs.appendingPathComponent("wine").path

                // 2. JIT Havuzu Tahsisi (Dual-mapped RX/RW bellek)
                guard let pool = StikJITHelper.allocatePool(poolSize: 128 * 1024 * 1024) else {
                    let failureMsg = StikJITHelper.poolFailure ?? "Hafıza havuzu oluşturulamadı."
                    print("[Revival] JIT havuzu tahsis edilemedi: \(failureMsg)")
                    DispatchQueue.main.async {
                        self.isStartingWine = false
                        self.wineStarted = false
                        self.wineCrashMessage = "JIT Havuz Hatası: \(failureMsg)"
                        self.showToast("❌ JIT hafıza havuzu açılamadı! Wine başlatılmadı.")
                        RevivalLogTelemetry.shared.uploadToDiscord(triggerReason: "pool-alloc-failure") { _, _ in }
                    }
                    return
                }

                setenv("WINE_IOS_JIT_RX", String(format: "%lx", Int(bitPattern: pool.rx)), 1)
                setenv("WINE_IOS_JIT_RW", String(format: "%lx", Int(bitPattern: pool.rw)), 1)
                setenv("WINE_IOS_JIT_SIZE", String(format: "%lx", pool.size), 1)
                if let hole = StikJITHelper.poolHole {
                    setenv("WINE_IOS_JIT_HOLE", String(format: "%lx:%lx", hole.off, hole.end), 1)
                }
                if let low = StikJITHelper.poolLow {
                    setenv("WINE_IOS_JIT_TAIL_REGION", String(format: "%lx:%lx", low.rx, low.size), 1)
                }
                StikJITHelper.detachDebugger()
                print("[Revival] JIT havuzu başarıyla tahsis edildi: \(pool.size / 1024 / 1024)MB")

                DispatchQueue.main.async {
                    self.statusMessage = "Oyun motoru başlatılıyor..."
                }

                // 3. Masaüstü Modu (Desktop Mode) Ortam Değişkenleri
                let deskW = 1408
                let deskH = 648
                setenv("MADEIRA_EXE", "explorer.exe", 1)
                setenv("MADEIRA_ARGS", "/desktop=shell,\(deskW)x\(deskH) C:\\Revival\\revival_launcher.exe", 1)
                setenv("MADEIRA_DESKTOP", "1", 1)
                setenv("MADEIRA_SCREEN_W", String(deskW), 1)
                setenv("MADEIRA_SCREEN_H", String(deskH), 1)
                setenv("MADEIRA_WAIT_CHILDREN", "1", 1)
                setenv("WINEDLLOVERRIDES", "winspool.drv=n,b;winspool=n,b;dinput8=n,b", 1)
                setenv("MADEIRA_CA_BUNDLE", "C:\\cacert.pem", 1)
                setenv("SSL_CERT_FILE", "C:\\cacert.pem", 1)
                setenv("d3d9", "native", 1)
                setenv("DXMT_CLEAR_DISCARD_STORE", "0", 1)
                setenv("QT_D3D_NO_FLIP", "1", 1)
                setenv("QT_D3D_FLIP_DISCARD", "0", 1)

                // 4. Wine Prefix'i Hazırla
                madeira_seed_prefix_if_needed(prefix)

                // 5. Wineserver Başlat ve Hazır Olmasını Bekle
                let srvResult = wineserver_start(prefix)
                print("[Revival] wineserver_start -> \(srvResult)")

                let waitStart = CFAbsoluteTimeGetCurrent()
                while wineserver_is_ready() == 0 && wineserver_is_running() != 0 && CFAbsoluteTimeGetCurrent() - waitStart < 3.0 {
                    Thread.sleep(forTimeInterval: 0.02)
                }
                print(String(format: "[Revival] wineserver hazır: %.0f ms", (CFAbsoluteTimeGetCurrent() - waitStart) * 1000))

                // 6. Ekran Çözünürlüğünü Bildir
                winios_display_mode_changed(Int32(deskW), Int32(deskH))

                // 7. Wine Sürecini Başlat
                let wineResult = wine_process_start(prefix)
                print("[Revival] wine_process_start -> \(wineResult)")

                // 8. Masaüstünü Ekrana Ver
                DispatchQueue.main.async {
                    MetalHostView.shared.isHidden = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isGameRunning = true
                        self.isStartingWine = false
                    }
                    // Arka planda süreç sağlığını izle (Watchdog)
                    self.startWineWatchdog()
                }
            }
        }
    }

    // MARK: - Wine Çalışma Zamanı Bekçisi (Watchdog)
    /// Wine süreci çöker veya kapanırsa uygulamanın aniden kapanmasını engeller, logları Discord'a aktarır ve başlatıcıya döner.
    private func startWineWatchdog() {
        DispatchQueue.global(qos: .background).async {
            // Wine'ın açılması için 4 saniye bekle
            Thread.sleep(forTimeInterval: 4.0)

            while self.isGameRunning {
                Thread.sleep(forTimeInterval: 1.5)

                if wineserver_is_running() == 0 || wine_process_is_running() == 0 {
                    print("[RevivalWatchdog] Wine süreci durdu veya kapandı!")
                    DispatchQueue.main.async {
                        MetalHostView.shared.isHidden = true
                        withAnimation {
                            self.isGameRunning = false
                            self.wineStarted = false
                            self.isStartingWine = false
                            self.wineCrashMessage = "Oyun beklenmedik şekilde kapandı. Hata logları Discord kanalına yüklendi."
                        }
                        RevivalLogTelemetry.shared.uploadToDiscord(triggerReason: "watchdog-wine-exit") { _, _ in }
                    }
                    break
                }
            }
        }
    }
}

// MARK: - UIActivityViewController SwiftUI Sarmalayıcısı
struct RevivalActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
