import Foundation

public struct AttentionReminder: Equatable, Sendable {
    public var kind: String
    public var date: Date
    public var message: String
}
public enum AttentionForecast {
    /// Forecasts use the real engine on a copy. Forecasting cannot grow the saved pet.
    public static func reminders(for state: GameState,database: ContentDatabase,from now: Date,horizonMinutes: Int = 720) throws -> [AttentionReminder] {
        guard state.playStyle != .sandbox,state.pet.life == .alive,now >= state.highWatermark,(1...1440).contains(horizonMinutes) else { return [] }
        var copy = state, result: [AttentionReminder] = [], seen: Set<String> = []
        try TimeEngine.advance(&copy,to: now,database: database)
        func append(_ kind: String,_ date: Date,_ message: String) {
            if seen.insert(kind).inserted { result.append(.init(kind: kind,date: date,message: message)) }
        }
        if let care = copy.pet.dmc {
            if copy.pet.isEgg {
                let date = care.eggStartedAt.addingTimeInterval(Double(database.colorRules(for: state.deviceID)?.hatchSeconds ?? 8))
                if date > now { append("hatch",date,"数码蛋即将孵化") }
            }
            if care.hungerCall != nil { append("hunger",now.addingTimeInterval(1),"伙伴空腹，请及时喂肉") }
            if care.strengthCall != nil { append("strength",now.addingTimeInterval(1),"伙伴力量不足，请训练或喂蛋白质") }
            if care.sleepCall != nil { append("sleep",now.addingTimeInterval(1),"伙伴需要睡眠，请关灯") }
        }
        for minute in 1...horizonMinutes {
            let date = now.addingTimeInterval(Double(minute*60)), before = copy.pet
            try TimeEngine.advance(&copy,to: date,database: database)
            if before.isEgg && !copy.pet.isEgg { append("hatch",date,"数码蛋已孵化，回来看看新伙伴") }
            if let care = copy.pet.dmc {
                if before.dmc?.hungerCall == nil,let call = care.hungerCall { append("hunger",max(now.addingTimeInterval(1),call),"伙伴空腹，请及时喂肉") }
                if before.dmc?.strengthCall == nil,let call = care.strengthCall { append("strength",max(now.addingTimeInterval(1),call),"伙伴力量不足，请训练或喂蛋白质") }
                if before.dmc?.sleepCall == nil,let call = care.sleepCall { append("sleep",max(now.addingTimeInterval(1),call),"伙伴需要睡眠，请关灯") }
            } else if copy.pet.stats.fullness == 0 && before.stats.fullness > 0 { append("hunger",date,"伙伴需要喂食") }
            if copy.pet.stats.waste > 0 && before.stats.waste == 0 { append("waste",date,"伙伴的环境需要清洁") }
            if copy.pet.life != .alive || result.count >= 5 { break }
        }
        return result.sorted { $0.date < $1.date }
    }
}
