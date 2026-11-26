import SwiftUI
import DigitalWorldCore

private struct GameLanguageKey: EnvironmentKey { static let defaultValue = AppLanguage.simplified }
extension EnvironmentValues {
    var gameLanguage: AppLanguage {
        get { self[GameLanguageKey.self] }
        set { self[GameLanguageKey.self] = newValue }
    }
}
