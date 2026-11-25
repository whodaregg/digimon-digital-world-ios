import SwiftUI

@main
struct DigitalWorldApp: App {
    @StateObject private var world = WorldViewModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            WorldView(model: world)
                .preferredColorScheme(.dark)
                .tint(Palette.mint)
                .onChange(of: phase) { _, newPhase in
                    if newPhase == .active { world.refresh(forceSave: true) }
                    else { world.refresh(forceSave: true); world.scheduleNotifications() }
                }
        }
    }
}
