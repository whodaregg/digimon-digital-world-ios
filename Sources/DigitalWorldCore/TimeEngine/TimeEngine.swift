import Foundation

public struct TimeReport: Equatable, Sendable {
    public var minutes = 0
    public var clockReversed = false
    public var hatchings = 0
    public var evolutions = 0
    public var deaths = 0
}

public enum TimeEngine {
    /// Minute steps are anchored to the saved cursor, independent of app reopen frequency.
    /// A fixed home timezone prevents travel from rewriting a pet's sleep schedule.
    @discardableResult
    public static func advance(_ state: inout GameState, to now: Date, database: ContentDatabase) throws -> TimeReport {
        if state.deviceID == DMCV1Engine.deviceID {
            let report = try DMCV1Engine.advance(&state,to: now,database: database)
            LifecycleManager.capture(&state); return report
        }
        guard now.timeIntervalSince1970.isFinite else { throw GameError.invalidData("时间无效") }
        let device = try database.device(state.deviceID)
        var report = TimeReport()
        guard now >= state.highWatermark else { report.clockReversed = true; return report }
        state.highWatermark = now
        let seconds = now.timeIntervalSince(state.lastTick)
        guard seconds >= 60 else { return report }
        // Avoid converting enormous imported timestamps to Int.
        guard seconds < Double(Int.max / 2) else { throw GameError.invalidData("时间跨度超出支持范围") }
        let count = Int(seconds / 60)
        let cursor = state.lastTick
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: state.homeTimeZone) ?? TimeZone(secondsFromGMT: 0)!
        // Every living pet has a <=90-day lifespan. No gameplay time is truncated:
        // once all pets are dead/frozen, the remaining interval needs only a cursor update.
        for step in 1...count {
            if !state.pets.contains(where: { $0.life == .alive }) { break }
            let date = cursor.addingTimeInterval(Double(step) * 60)
            for index in state.pets.indices where state.pets[index].life == .alive {
                var p = state.pets[index]
                p.activeMinutes += 1; p.stageMinutes += 1
                if p.isEgg {
                    if p.stageMinutes >= (try database.egg(p.eggID)).hatchMinutes {
                        p.isEgg = false; p.stageMinutes = 0; p.activeMinutes = 0
                        p.evolutionHistory = [p.speciesID]; p.appearances = [SpeciesAppearance(p.speciesID,at: date)]
                        p.record("hatch", "孵化 · \((try database.species(p.speciesID)).name)", at: date)
                        state.dex[p.speciesID] = .raised; report.hatchings += 1
                    }
                    state.pets[index] = p
                    continue
                }
                let species = try database.species(p.speciesID)
                let hour = calendar.component(.hour, from: date)
                let scheduledSleep = isSleepHour(hour, sleep: species.sleepHour, wake: species.wakeHour)
                p.sleeping = scheduledSleep || p.manualRest
                if p.sleeping {
                    if p.activeMinutes % 5 == 0 { p.stats.energy += 2; p.stats.stamina += 2 }
                    if !p.lightsOff {
                        p.sleepNeglectMinutes += 1
                        if p.sleepNeglectMinutes == device.careGraceMinutes {
                            p.stats.mistakes += 1; p.record("care", "睡眠期间未关灯", at: date)
                        }
                    } else { p.sleepNeglectMinutes = 0 }
                } else {
                    p.sleepNeglectMinutes = 0; p.awakeMinutes += 1
                    if p.awakeMinutes % device.hungerEveryMinutes == 0 { p.stats.fullness -= 10 }
                    if p.awakeMinutes % device.strengthEveryMinutes == 0 { p.stats.strength -= 5; p.stats.happiness -= 3 }
                    if p.awakeMinutes % 20 == 0 { p.stats.energy -= 1; p.stats.stamina += 1; p.stats.dp += 1 }
                    if p.awakeMinutes % device.wasteEveryMinutes == 0 { p.stats.waste += 1 }
                }
                if p.stats.waste > 0 {
                    p.dirtyMinutes += 1
                    if p.dirtyMinutes >= 120 && !p.stats.sick {
                        p.stats.sick = true; p.stats.illnesses += 1
                        p.record("illness", "环境不洁，需要治疗", at: date)
                    }
                } else { p.dirtyMinutes = 0 }
                let needsCare = p.stats.fullness <= 0 || p.stats.energy <= 0
                if needsCare {
                    p.neglectMinutes += 1
                    if p.neglectMinutes % device.careGraceMinutes == 0 {
                        p.stats.mistakes += 1; p.stats.health -= 5
                        p.record("care", "未及时响应养成呼叫", at: date)
                    }
                } else { p.neglectMinutes = 0 }
                if p.stats.sick && p.activeMinutes % 30 == 0 { p.stats.health -= 3 }
                if p.activeMinutes % 60 == 0 && !p.stats.sick && !needsCare { p.stats.health += 1 }
                p.stats.clamp()
                if p.stats.health == 0 || p.activeMinutes >= species.lifespanMinutes {
                    p.life = .dead; p.sleeping = false
                    p.record("death", "回归数据，养成记录已保留", at: date); report.deaths += 1
                    if state.training?.petID == p.id { state.training = nil }
                } else if let rule = try EvolutionEngine.candidate(pet: p, database: database, inventory: state.inventory) {
                    p.appearances = (p.appearances ?? []) + [SpeciesAppearance(rule.target,at: date)]
                    p.speciesID = rule.target; p.stageMinutes = 0; p.evolutionHistory.append(rule.target)
                    p.developerTuning = nil
                    if let item = rule.requiredItem { state.inventory[item, default: 0] -= 1 }
                    state.dex[rule.target] = .raised
                    p.record("evolution", "进化 · \((try database.species(rule.target)).name)", at: date)
                    if state.training?.petID == p.id { state.training = nil }
                    report.evolutions += 1
                }
                state.pets[index] = p
            }
        }
        report.minutes = count
        state.lastTick = cursor.addingTimeInterval(Double(count) * 60)
        if let session = state.training, now.timeIntervalSince(session.startedAt) > 30 { state.training = nil }
        LifecycleManager.capture(&state)
        return report
    }
    public static func isSleepHour(_ hour: Int, sleep: Int, wake: Int) -> Bool {
        sleep < wake ? (hour >= sleep && hour < wake) : (hour >= sleep || hour < wake)
    }
}
