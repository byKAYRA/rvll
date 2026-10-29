import Foundation
import SwiftUI
import UIKit

// MARK: - Revival Mobile (Goley TR) Ana Görünümü
// Eski Steam/Madeira kütüphanesi yerine doğrudan Revival oyununa özel tasarlanmış görünüm.
struct RevivalRootView: View {
    @ObservedObject private var touchModel = TouchControlsModel.shared
    @State private var isGameRunning = false
    @State private var statusMessage = "Revival başlatılıyor..."
    @State private var showControls = true
    @State private var wineStarted = false

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
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                                    .scaleEffect(1.3)

                                Text(statusMessage)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .padding(.bottom, 40)
                        }
                    }
                    .transition(.opacity)
                }

                // 5. Minimalist Üst Kontrol Barı (Oyun açıkken gizlenebilir)
                VStack {
                    HStack {
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

                        Spacer()

                        // Çıkış / Kapat
                        Button {
                            exit(0)
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

        statusMessage = "Kontroller ve yapılandırma hazırlanıyor..."
        
        // Goley Futbol Kontrollerini Varsayılan Olarak Yükle
        let screen = ControlPresetScreen(
            width: geo.size.width,
            height: geo.size.height,
            left: 16, right: 16, top: 8, bottom: 8
        )
        ControlPresetsModel.shared.load(ControlPresetLayout.goleyID, screen: screen, reason: "revival-start")

        // Çevre Değişkenleri
        setenv("MADEIRA_EXE", "C:\\Revival\\revival_launcher.exe", 1)
        setenv("WINEDLLOVERRIDES", "winspool.drv=n,b;winspool=n,b;dinput8=n,b", 1)
        setenv("MADEIRA_CA_BUNDLE", "C:\\cacert.pem", 1)
        setenv("SSL_CERT_FILE", "C:\\cacert.pem", 1)
        setenv("d3d9", "native", 1)
        setenv("DXMT_CLEAR_DISCARD_STORE", "0", 1)
        setenv("QT_D3D_NO_FLIP", "1", 1)
        setenv("QT_D3D_FLIP_DISCARD", "0", 1)

        statusMessage = "Oyun motoru başlatılıyor..."

        // Wine Server ve Süreç Başlatma
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
