import Foundation

public enum DeviceKey: String, Codable, CaseIterable, Hashable, Sendable { case a = "A", b = "B", c = "C" }
public enum LCDScreen: String, Sendable {
    case home, status, food, training, areas, battle, power, clock, sound, confirmBackup, confirmRebirth, deviceSettings, settingValue, displayOff, clockEdit
}
public enum LCDCommand: Equatable, Sendable {
    case none, feedback, feed(String), beginTraining, train(String), cancelTraining, quest(Int), clean, medicine
    case lights, cold, backup, rebirth, sound(Bool), skipBattle, brightness(Double), volume(Double), background(String), clock(Int,Int)
}
public struct DeviceInputRouter: Sendable {
    public var screen: LCDScreen = .home
    public var selectedIcon: Int?
    public var item = 0
    public var statusPage = 0
    public var setting = 0
    public var choice = 0
    public var clockHour = 0, clockMinute = 0
    private var pressed: [DeviceKey:Date] = [:]
    private var consumed: Set<DeviceKey> = []
    private var lastReleased: Date?
    public init() {}
    public mutating func open(icon: Int,state: GameState) -> LCDCommand {
        guard (0..<7).contains(icon) else { return .none }
        selectedIcon = icon; item = 0
        switch icon {
        case 0: screen = .status; statusPage = 0
        case 1: screen = .food
        case 2: screen = .training
        case 3: screen = .areas
        case 4: screen = .home; return .clean
        case 5: screen = .power
        default: screen = .home; return .medicine
        }
        return .feedback
    }
    public mutating func keyDown(_ key: DeviceKey,at date: Date,state: GameState? = nil) -> LCDCommand {
        guard pressed[key] == nil else { return .none }
        pressed[key] = date
        if screen == .clock,let state,pressed[.a] != nil,pressed[.c] != nil {
            consumed.formUnion([.a,.c]); screen = .clockEdit
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: state.homeTimeZone) ?? .current
            let value = calendar.dateComponents([.hour,.minute],from: DeviceClock.displayedDate(for: state,at: SandboxEngine.date(for: state,wallTime: date)))
            clockHour = value.hour ?? 0; clockMinute = value.minute ?? 0; return .feedback
        }
        if screen == .home,let state,state.pet.life == .dead,pressed[.a] != nil,pressed[.b] != nil {
            consumed.formUnion([.a,.b]); return .rebirth
        }
        if screen == .home,selectedIcon == nil,pressed[.a] != nil,pressed[.c] != nil {
            consumed.formUnion([.a,.c]); return .sound(!(state?.settings.sound ?? true))
        }
        return .none
    }
    public mutating func keyUp(_ key: DeviceKey,at date: Date,state: GameState,availableAreas: Int) -> LCDCommand {
        guard let began = pressed.removeValue(forKey: key) else { return .none }
        if consumed.remove(key) != nil { return .none }
        guard date >= began,date.timeIntervalSince(began) < 20 else { return .none }
        if let lastReleased,date.timeIntervalSince(lastReleased) < 0.12 { return .none }
        lastReleased = date
        let duration = date.timeIntervalSince(began),held = duration >= 0.65
        if screen == .displayOff { screen = .home; return .feedback }
        if screen == .home && selectedIcon == nil && key == .c && duration >= 2 {
            screen = .deviceSettings; item = 0; return .feedback
        }
        if held && key == .c && screen != .battle && state.playStyle != .classic {
            let cancel = state.training != nil
            screen = .home; selectedIcon = nil; item = 0
            return cancel ? .cancelTraining : .feedback
        }
        if screen == .home {
            if state.pet.life == .dead && state.playStyle == .classic { return .feedback }
            if key == .a { selectedIcon = selectedIcon.map { ($0+1)%7 } ?? 0 }
            if key == .b {
                if state.pet.life == .dead { screen = .confirmRebirth; item = 0 }
                else if let selectedIcon { return open(icon: selectedIcon,state: state) }
                else { screen = .clock }
            }
            if key == .c { selectedIcon = nil }
            return .feedback
        }
        if screen == .battle { return key == .b && state.playStyle != .classic ? .skipBattle : .none }
        if screen == .clockEdit && key == .c { screen = .clock; return .clock(clockHour,clockMinute) }
        if key == .c {
            if screen == .settingValue { screen = .deviceSettings; return .feedback }
            let cancel = screen == .training && state.training != nil
            screen = .home; selectedIcon = nil; item = 0
            return cancel ? .cancelTraining : .feedback
        }
        switch screen {
        case .clock:
            if key == .b { screen = .home }
        case .clockEdit:
            if key == .a { clockHour = (clockHour+1)%24 }
            if key == .b { clockMinute = (clockMinute+1)%60 }
        case .deviceSettings:
            if key == .a { item = (item+1)%4 }
            if key == .b {
                if item == 3 { screen = .displayOff }
                else {
                    setting = item; screen = .settingValue
                    if setting == 0 { choice = state.dmc?.backgrounds.sorted().firstIndex(of: state.dmc?.selectedBackground ?? "grasslands") ?? 0 }
                    else { choice = setting == 1 ? min(4,max(0,Int(((state.settings.presentation.brightness-0.3)/0.7*4).rounded()))) : Int((state.settings.presentation.volume*4).rounded()) }
                }
            }
        case .settingValue:
            let backgrounds = state.dmc?.backgrounds.sorted() ?? ["grasslands"]
            if key == .a { choice = (choice+1)%(setting == 0 ? backgrounds.count : 5) }
            if key == .b {
                screen = .deviceSettings
                if setting == 0 { return .background(backgrounds[choice]) }
                if setting == 1 { return .brightness(0.3+Double(choice)*0.175) }
                return .volume(Double(choice)/4)
            }
        case .status:
            if key != .c { statusPage = (statusPage+1)%(state.playStyle == .classic ? 6 : 8) }
        case .food:
            if key == .a { item = (item+1)%2 }
            if key == .b { return .feed(item == 0 ? "meat" : "protein") }
        case .training:
            if state.training != nil { return .train(key == .a ? "A" : "B") }
            if key == .b { return .beginTraining }
        case .areas:
            if key == .a { item = (item+1)%max(1,min(8,availableAreas)) }
            if key == .b { return .quest(item+1) }
        case .power:
            if key == .a { item = (item+1)%3 }
            if key == .b {
                if item == 0 { return .lights }
                if item == 1 { return .cold }
                screen = .confirmBackup; item = 0
            }
        case .confirmBackup:
            if key == .a { item = (item+1)%2 }
            if key == .b { screen = .home; return item == 1 ? .backup : .feedback }
        case .confirmRebirth:
            if key == .a { item = (item+1)%2 }
            if key == .b { screen = .home; return item == 1 ? .rebirth : .feedback }
        case .sound:
            if key == .a { item = (item+1)%2 }
            if key == .b { screen = .home; return .sound(item == 0) }
        default: break
        }
        return .feedback
    }
    public mutating func cancelTouches() { pressed = [:]; consumed = [] }
    public mutating func returnHome() { screen = .home; selectedIcon = nil; item = 0; cancelTouches() }
}
