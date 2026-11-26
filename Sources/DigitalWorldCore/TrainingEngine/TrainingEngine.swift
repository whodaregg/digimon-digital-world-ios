import Foundation

public enum TrainingEngine {
    public static let roundSeconds = 2.0
    public static let target = 0.72
    public static func position(elapsed: Double) -> Double {
        let phase = max(0, elapsed).truncatingRemainder(dividingBy: roundSeconds) / roundSeconds
        return 1 - abs(2 * phase - 1)
    }
    public static func score(taps: [Double]) -> Int {
        guard taps.count == 3 else { return 0 }
        let accuracy = taps.map { max(0, 1 - abs(position(elapsed: $0) - target) / 0.35) }
        return Int((accuracy.reduce(0, +) / 3 * 100).rounded())
    }
    public static func begin(_ state: inout GameState, at now: Date) throws {
        guard !DeviceRegistry.isColor(state.deviceID) else { return try DMCV1Engine.beginTraining(&state,at: now) }
        guard state.training == nil else { throw GameError.cannotAct("训练已开始，请完成或取消") }
        guard state.pet.life == .alive, !state.pet.isEgg, !state.pet.sleeping,
              !state.pet.stats.sick, !state.pet.stats.injured, state.pet.stats.energy >= 10 else {
            throw GameError.cannotAct("需要清醒、健康且能量不少于 10 的伙伴")
        }
        state.training = TrainingSession(id: UUID(), petID: state.activePetID, startedAt: now)
        state.pets[state.activeIndex].stats.energy -= 5
        state.pets[state.activeIndex].stats.trainingAttempts += 1
    }
    /// Taps derive from elapsed wall time at receipt; callers cannot submit arbitrary scores.
    @discardableResult
    public static func tap(_ state: inout GameState, sessionID: UUID, at now: Date) throws -> Int? {
        guard !DeviceRegistry.isColor(state.deviceID) else { throw GameError.cannotAct("Ver.1 请使用 A/B 上下段训练") }
        guard var session = state.training, session.id == sessionID, session.petID == state.activePetID else {
            throw GameError.cannotAct("训练已结束或失效")
        }
        let elapsed = now.timeIntervalSince(session.startedAt)
        guard elapsed >= 0, elapsed <= 15, session.taps.count < 3 else {
            state.training = nil; throw GameError.cannotAct("训练超时，请重新开始")
        }
        if let last = session.taps.last, elapsed - last < 0.25 { throw GameError.cannotAct("请等待下一次时机") }
        session.taps.append(elapsed)
        state.training = session
        guard session.taps.count == 3 else { return nil }
        let result = score(taps: session.taps)
        let index = state.activeIndex
        if result >= 60 {
            state.pets[index].stats.training += 1
            state.pets[index].stats.strength += 8
            state.pets[index].stats.bond += 2
            state.pets[index].stats.loyalty += 2
        }
        state.pets[index].stats.happiness += result >= 60 ? 5 : -2
        state.pets[index].stats.weight -= 1
        state.pets[index].stats.clamp()
        state.pets[index].record("training", "精准训练 \(result) 分 · \(result >= 60 ? "成功" : "继续努力")", at: now)
        state.training = nil
        return result
    }
}
