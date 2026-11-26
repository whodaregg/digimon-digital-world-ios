import Foundation

public enum SandboxEngine {
    @discardableResult public static func advance(_ state: inout GameState,minutes: Int,wallTime: Date,database: ContentDatabase) throws -> TimeReport {
        guard state.playStyle == .sandbox,state.developerModifiedAt != nil,(1...43_200).contains(minutes) else {
            throw GameError.cannotAct("仅独立Sandbox允许推进测试时间")
        }
        var candidate = state
        let offset = (candidate.sandboxOffsetSeconds ?? 0)+minutes*60
        guard offset <= 315_360_000 else { throw GameError.cannotAct("Sandbox虚拟时间偏移已达到十年上限") }
        candidate.sandboxOffsetSeconds = offset
        let report = try TimeEngine.advance(&candidate,to: wallTime.addingTimeInterval(Double(offset)),database: database)
        guard !report.clockReversed else { throw GameError.cannotAct("系统时间早于Sandbox记录，请先恢复系统时间") }
        try database.validateSave(candidate); state = candidate; return report
    }
    public static func date(for state: GameState,wallTime: Date) -> Date {
        wallTime.addingTimeInterval(state.playStyle == .sandbox ? Double(state.sandboxOffsetSeconds ?? 0) : 0)
    }
}
