import SwiftUI
import DigitalWorldCore

@main
struct DigitalWorldApp: App {
    @StateObject private var world = WorldViewModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            WorldView(model: world)
                .environment(\.gameLanguage,world.language)
                .environment(\.locale,Locale(identifier: world.language.rawValue))
                .preferredColorScheme(.dark)
                .tint(Palette.mint)
                .onChange(of: phase) { _, newPhase in
                    if newPhase == .active { world.refresh(forceSave: true); world.cloud.refresh() }
                    else { world.refresh(forceSave: true); world.scheduleNotifications(); world.cloud.upload(model: world,force: false) }
                }
        }
    }
}
