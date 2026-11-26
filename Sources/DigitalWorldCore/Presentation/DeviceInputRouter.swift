import Foundation

public enum DeviceKey: String, Codable, CaseIterable, Hashable, Sendable { case a = "A", b = "B", c = "C" }
public enum LCDScreen: String, Sendable {
    case home, status, food, training, areas, battle, power, clock, sound, confirmBackup, confirmRebirth
}
public enum LCDCommand: Equatable, Sendable {
    case none, feedback, feed(String), beginTraining, train(String), cancelTraining, quest(Int), clean, medicine
    case lights, cold, backup, rebirth, sound(Bool), skipBattle
}
public struct DeviceInputRouter: Sendable {
    public var screen: LCDScreen = .home
    public var selectedIcon: Int?
    public var item = 0
    public var statusPage = 0
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
    public mutating func keyDown(_ key: DeviceKey,at date: Date) -> LCDCommand {
        guard pressed[key] == nil else { return .none }
        pressed[key] = date
        // The COLOR sound shortcut is C held while pressing A on the normal screen.
        if screen == .home,pressed[.a] != nil,pressed[.c] != nil {
            consumed.formUnion([.a,.c]); screen = .sound; item = 0; return .feedback
        }
        return .none
    }
    public mutating func keyUp(_ key: DeviceKey,at date: Date,state: GameState,availableAreas: Int) -> LCDCommand {
        guard let began = pressed.removeValue(forKey: key) else { return .none }
        if consumed.remove(key) != nil { return .none }
        guard date >= began,date.timeIntervalSince(began) < 20 else { return .none }
        if let lastReleased,date.timeIntervalSince(lastReleased) < 0.12 { return .none }
        lastReleased = date
        let held = date.timeIntervalSince(began) >= 0.65
        if held && key == .c && screen != .battle {
            let cancel = state.training != nil
            screen = .home; selectedIcon = nil; item = 0
            return cancel ? .cancelTraining : .feedback
        }
        if screen == .home {
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
        if key == .c {
            let cancel = screen == .training && state.training != nil
            screen = .home; selectedIcon = nil; item = 0
            return cancel ? .cancelTraining : .feedback
        }
        switch screen {
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
