import Foundation
import SwiftUI
import UIKit

// MARK: - Revival Mobile (Goley TR) Ana Görünümü
struct RevivalRootView: View {
    @ObservedObject private var touchModel = TouchControlsModel.shared
    @ObservedObject private var syncEngine = RevivalSyncEngine.shared

    @State private var isGameRunning = false
    @State private var statusMessage = "Revival hazırlanıyor..."
    @State private var showControls = true
    @State private var wineStarted = false
    @State private var isUploadingLogs = false
    @State private var toastMessage: String? = nil
    @State private var showJITSheet = false
    @State private var isJITReady = StikJITHelper.ready
    @State private var showLogMenu = false
    @State private var shareURL: URL? = nil
    @State private var showShareSheet = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Zemin Siyah Arka Plan
                Color.black.ignoresSafeArea()

                // 2. Metal Render Katmanı (Wine / Windows Explorer Desktop / DXMT)
                MadeiraMetalView()
                    .ignoresSafeArea()

                // 3. Dokunmatik Futbol Kontrolleri (Goley Kontrolleri)
                if showControls {
                    TouchControlsOverlay()
                        .ignoresSafeArea()
                }

                // 4. Açılış / Güncelleme Splash Ekranı (Desktop oturumu başlayana kadar görünür)
                if !isGameRunning {
                    ZStack {
                        Color(red: 0.05, green: 0.07, blue: 0.12)
                            .ignoresSafeArea()

                        VStack(spacing: 24) {
                            Spacer()

                            // Revival Logo / Başlık
                            VStack(spacing: 8) {
                                Text("REVIVAL")
                                    .font(.system(size: 42, weight: .black, design: .rounded))
                                    .tracking(4)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.green, Color.mint, Color.cyan],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: .green.opacity(0.5), radius: 12, x: 0, y: 4)

                                Text("GOLEY MOBILE")
                                    .font(.system(size: 14, weight: .bold))
                                    .tracking(6)
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            Spacer()

                            // Durum / İlerleme Göstergesi
                            VStack(spacing: 14) {
                                if syncEngine.isSyncing {
                                    ProgressView(value: max(0.05, syncEngine.progressFraction))
                                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                        .frame(width: 260)
                                        .scaleEffect(x: 1, y: 2, anchor: .center)

                                    Text(syncEngine.progressText)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.9))
                                } else {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                        .scaleEffect(1.3)

                                    Text(statusMessage)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.85))
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                    .transition(.opacity)
                }

                // 5. Minimalist Üst Kontrol Barı
                VStack {
                    HStack(spacing: 10) {
                        // Kontrolleri Aç/Kapat
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

                        // JIT Durumu ve Dahili JIT Menüsü (⚡)
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

                        // Teşhis / Log Menüsü (Filebin + Share Sheet)
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
            .onAppear {
                isJITReady = StikJITHelper.ready
                startRevivalSession(geo: geo)
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
                Button("Buluta Yükle (Filebin.net)") {
                    uploadLogsToFilebin()
                }
                Button("Log Dosyasını Paylaş / Kaydet (AirDrop / Dosyalar)") {
                    exportAndShareLogs()
                }
                Button("İptal", role: .cancel) {}
            }
        }
    }

    private func uploadLogsToFilebin() {
        isUploadingLogs = true
        showToast("Loglar toplanıyor ve buluta iletiliyor...")
        RevivalLogTelemetry.shared.uploadLogs(triggerReason: "user-button") { success, msg in
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

    private func startRevivalSession(geo: GeometryProxy) {
        guard !wineStarted else { return }
        wineStarted = true

        // Goley Futbol Kontrollerini Yükle
        let screen = ControlPresetScreen(
            width: geo.size.width,
            height: geo.size.height,
            left: 16, right: 16, top: 8, bottom: 8
        )
        ControlPresetsModel.shared.load(ControlPresetLayout.goleyID, screen: screen, reason: "revival-start")

        Task {
            // 1. GitHub Güncellemelerini Denetle
            statusMessage = "Güncellemeler denetleniyor..."
            await syncEngine.synchronize()

            statusMessage = "Oyun motoru hazırlanıyor..."

            DispatchQueue.global(qos: .userInteractive).async {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let prefix = docs.appendingPathComponent("wine").path

                // 2. JIT Havuzu Tahsisi (JIT hazırsa dual-mapped bellek oluşturulur)
                if StikJITHelper.ready {
                    if let pool = StikJITHelper.allocatePool(poolSize: 128 * 1024 * 1024) {
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
                        print("[Revival] JIT havuzu tahsis edildi: \(pool.size / 1024 / 1024)MB")
                    } else {
                        print("[Revival] JIT hazır görünüyor ancak havuz oluşturulamadı.")
                    }
                } else {
                    print("[Revival] UYARI: JIT henüz etkin değil!")
                    DispatchQueue.main.async {
                        self.showToast("⚠️ JIT henüz aktif değil! Üstteki ⚡ butonundan açabilirsiniz.")
                    }
                }

                // 3. Masaüstü Modu (Desktop Mode) Ortam Değişkenleri
                // Ekranı gizlemeden, Windows Desktop shell'i ve Launcher penceresini doğrudan ekrana basar.
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

                // 8. Masaüstünü Hemen Ekrana Ver (Simsiyah ekran kalmasını önle)
                DispatchQueue.main.async {
                    MetalHostView.shared.isHidden = false
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isGameRunning = true
                    }
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
