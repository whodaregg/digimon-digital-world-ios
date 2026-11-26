import Foundation
import DigitalWorldCore

extension WorldViewModel {
    var language: AppLanguage { state?.settings.presentation.language ?? .simplified }
    func text(_ key: DeviceText) -> String { key.text(language) }
    func lcdTouch(_ icon: Int) {
        guard touchEnabled,let state else { return }
        lcdNotice = nil
        feedbackTap()
        emitAudio(.menuSelect)
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
        let action = lcd.keyUp(key,at: Date(),state: state,availableAreas: min(8,(state.dmc?.clearedAreas.max() ?? 0)+1))
        if lcd.screen == .settingValue, lcd.setting == 2, previous != .settingValue {
            lcd.choice = Int((audioAssets.settings(for: state.deviceID).volume(.sfx) * 4).rounded())
        }
        performLCD(action)
        guard action != .none else { return }
        if previous == .displayOff && lcd.screen != .displayOff { emitAudio(.powerOn) }
        else if previous != .displayOff && lcd.screen == .displayOff { emitAudio(.powerOff) }
        else if key == .a { emitAudio(.menuSelect) }
        else if key == .c { emitAudio(.cancel) }
        else if lcdNotice == nil { emitAudio(.confirm) }
        if previous == .home,[LCDScreen.food,.training,.areas].contains(lcd.screen) { openCareCommand() }
    }
    func performLCD(_ action: LCDCommand) {
        switch action {
        case .none, .feedback: return
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
        case .volume(let value):
            if let id = state?.deviceID {
                audioAssets.update(id) { $0.volumes[.sfx] = value }
                syncAudio()
            }
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
