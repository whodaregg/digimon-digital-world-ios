import Foundation
import DigitalWorldCore

extension WorldViewModel {
    var language: AppLanguage { state?.settings.presentation.language ?? .simplified }
    func text(_ key: DeviceText) -> String { key.text(language) }
    func lcdTouch(_ icon: Int) {
        guard touchEnabled,let state else { return }
        lcdNotice = nil
        if [1,2,3].contains(icon) { openCareCommand() }
        performLCD(lcd.open(icon: icon,state: state))
    }
    func lcdKeyDown(_ key: DeviceKey) { performLCD(lcd.keyDown(key,at: Date(),state: state)); feedbackTap() }
    func lcdKeyUp(_ key: DeviceKey) {
        guard let state else { return }
        if lcd.screen == .food,isFeeding,key != .c { lcd.cancelTouches(); return }
        lcdNotice = nil
        if lcd.screen == .battle && lcdBattleFinished && (key == .b || key == .c) {
            _ = lcd.keyUp(key,at: Date(),state: state,availableAreas: 8); finishLCDQuest(); return
        }
        let previous = lcd.screen
        performLCD(lcd.keyUp(key,at: Date(),state: state,availableAreas: min(8,(state.dmc?.clearedAreas.max() ?? 0)+1)))
        if previous == .home,[LCDScreen.food,.training,.areas].contains(lcd.screen) { openCareCommand() }
    }
    func performLCD(_ action: LCDCommand) {
        switch action {
        case .none: return
        case .feedback: feedbackTap(); return
        case .feed(let id):
            guard !isFeeding else { return }
            feedingFoodID = id; care(.feed(id))
        case .beginTraining: beginTraining()
        case .train(let key): originalTraining(key)
        case .cancelTraining: cancelTraining()
        case .quest(let area): quest(area); if lastQuest != nil { lcd.screen = .battle }
        case .clean: care(.clean)
        case .medicine: care(.medicine)
        case .lights: care(.lights(!(state?.pet.lightsOff ?? false)))
        case .cold: care(.freeze(state?.pet.life != .frozen))
        case .backup: swapBackup()
        case .rebirth: care(.rebirth(state?.pet.eggID ?? "dmc-v1-egg"))
        case .sound(let on): settings { $0.sound = on }
        case .skipBattle: lcdSkipRequest += 1
        case .brightness(let value): editPresentation { $0.brightness = value }
        case .volume(let value): editPresentation { $0.volume = value }
        case .background(let id): selectBackground(id)
        case .clock(let hour,let minute): setDeviceClock(hour: hour,minute: minute)
        }
        if let failure = alert {
            alert = nil; lcdNotice = failure
            if case .feed = action { play("refuse") }
        } else { lcdNotice = nil }
    }
    func finishLCDQuest() { lastQuest = nil; lcd.screen = .areas }
}
