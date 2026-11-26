import Foundation

/// Device time-of-day is separate from elapsed growth time and the anti-replay watermark.
public enum DeviceClock {
    public static func displayedDate(for state: GameState,at date: Date) -> Date {
        date.addingTimeInterval(Double(state.clockOffsetSeconds ?? 0))
    }
    public static func set(hour: Int,minute: Int,state: inout GameState,at date: Date) throws {
        guard (0...23).contains(hour),(0...59).contains(minute),date >= state.highWatermark else { throw GameError.cannotAct("时钟设置无效或系统时间发生倒退") }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: state.homeTimeZone) ?? .current
        let current = calendar.dateComponents([.hour,.minute,.second],from: date)
        let offset = hour*3600+minute*60-((current.hour ?? 0)*3600+(current.minute ?? 0)*60+(current.second ?? 0))
        state.clockOffsetSeconds = offset
        state.pets[state.activeIndex].record("clock","设备时钟已设置；成长仍按真实经过时间计算",at: date)
    }
}
