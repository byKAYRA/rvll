import Foundation
import SwiftUI

@main
struct RevivalApp: App {
    init() {
        // Opt-in iPhone pointer experiments
        madeira_phone_pointer_setup()
        
        // Metal HUD off
        setenv("MTL_HUD_INSIGHTS_ENABLED", "0", 0)
        
        // Host pads as Windows.Gaming.Input gamepads
        setenv("MADEIRA_WGI_HOST_PADS", "1", 0)
        
        _ = ResolutionChoices.screen
        SigningAccountStore.takeIn()
        ProfileUnification.run()
    }

    var body: some Scene {
        WindowGroup {
            RevivalRootView()
                .background(InteractionFrameRateInstaller())
                .modifier(ClaimGamepadEvents())
                .onAppear {
                    ExternalDrives.shared.mountAll()
                    GamepadInput.shared.start()
                    HardwareInput.shared.start()
                }
        }
    }
}
