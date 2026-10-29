import Foundation
import SwiftUI
import UIKit

// MARK: - Revival Mobile (Goley TR) Ana Görünümü
// Eski Steam/Madeira kütüphanesi yerine doğrudan Revival oyununa özel tasarlanmış görünüm.
struct RevivalRootView: View {
    @ObservedObject private var touchModel = TouchControlsModel.shared
    @ObservedObject private var syncEngine = RevivalSyncEngine.shared

    @State private var isGameRunning = false
    @State private var statusMessage = "Revival hazırlanıyor..."
    @State private var showControls = true
    @State private var wineStarted = false
    @State private var isUploadingLogs = false
    @State private var toastMessage: String? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. Zemin Siyah Arka Plan
                Color.black.ignoresSafeArea()

                // 2. Metal Render Katmanı (Wine / D3D9 / DXMT)
                MadeiraMetalView()
                    .ignoresSafeArea()

                // 3. Dokunmatik Futbol Kontrolleri (Goley Kontrolleri)
                if showControls {
                    TouchControlsOverlay()
                        .ignoresSafeArea()
                }

                // 4. Açılış / Yükleme Splash Ekranı (Oyun açılana kadar görünür)
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

                // 5. Minimalist Üst Kontrol Barı (Oyun açıkken de kullanılabilir)
                VStack {
                    HStack(spacing: 12) {
                        // Kontrolleri Aç/Kapat
                        Button {
                            showControls.toggle()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: showControls ? "gamecontroller.fill" : "gamecontroller")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(showControls ? 0.95 : 0.4))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        // Sanal Klavye Aç/Kapat
                        Button {
                            MetalBackedView.toggleKeyboard()
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "keyboard")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        // Teşhis / Log Gönder Butonu (GitHub Gist)
                        Button {
                            isUploadingLogs = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            RevivalLogTelemetry.shared.uploadLogs(triggerReason: "user-button") { success, msg in
                                isUploadingLogs = false
                                withAnimation {
                                    toastMessage = msg
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                    withAnimation {
                                        toastMessage = nil
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: isUploadingLogs ? "arrow.triangle.2.circlepath" : "ladybug")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(isUploadingLogs ? .yellow : .white.opacity(0.9))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }

                        Spacer()

                        // Çıkış / Kapat
                        Button {
                            // Çıkışta logları sessizce ilet
                            RevivalLogTelemetry.shared.uploadLogs(triggerReason: "exit-button")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                exit(0)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(10)
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
                            .background(Color.black.opacity(0.8))
                            .clipShape(Capsule())
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()
                }
            }
            .onAppear {
                startRevivalSession(geo: geo)
            }
        }
    }

    private func startRevivalSession(geo: GeometryProxy) {
        guard !wineStarted else { return }
        wineStarted = true

        // Goley Futbol Kontrollerini Varsayılan Olarak Yükle
        let screen = ControlPresetScreen(
            width: geo.size.width,
            height: geo.size.height,
            left: 16, right: 16, top: 8, bottom: 8
        )
        ControlPresetsModel.shared.load(ControlPresetLayout.goleyID, screen: screen, reason: "revival-start")

        // Çevre Değişkenleri
        setenv("MADEIRA_EXE", "C:\\Revival\\revival_launcher.exe", 1)
        setenv("MADEIRA_WAIT_CHILDREN", "1", 1) // Launcher BinaryTrU.exe'yi başlattığında oturumu açık tut
        setenv("WINEDLLOVERRIDES", "winspool.drv=n,b;winspool=n,b;dinput8=n,b", 1)
        setenv("MADEIRA_CA_BUNDLE", "C:\\cacert.pem", 1)
        setenv("SSL_CERT_FILE", "C:\\cacert.pem", 1)
        setenv("d3d9", "native", 1)
        setenv("DXMT_CLEAR_DISCARD_STORE", "0", 1)
        setenv("QT_D3D_NO_FLIP", "1", 1)
        setenv("QT_D3D_FLIP_DISCARD", "0", 1)

        Task {
            // 1. GitHub Üzerinden Güncellemeleri Denetle
            statusMessage = "Güncellemeler denetleniyor..."
            await syncEngine.synchronize()

            statusMessage = "Oyun motoru başlatılıyor..."

            // 2. Wine Server ve Süreç Başlatma
            DispatchQueue.global(qos: .userInteractive).async {
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let prefix = docs.appendingPathComponent("wine").path

                // Prefix'i hazırla ve seed et
                madeira_seed_prefix_if_needed(prefix)

                // Wine başlat
                _ = wine_process_start(prefix)

                // Oyun penceresinin hazır olduğunu kontrol et
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        self.isGameRunning = true
                    }
                }
            }
        }
    }
}
