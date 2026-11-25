import Foundation

/// COLOR Ver.1's care loop. Legacy experimental saves use their original engines.
public enum DMCV1Engine {
    public static let deviceID = "dmc-ver1"
    public static func rules(_ database: ContentDatabase) throws -> DMCV1Rules {
        guard let rules = database.dmcV1 else { throw GameError.invalidData("缺少 Ver.1 数据") }
        return rules
    }
    static func sync(_ p: inout Pet) {
        guard let c = p.dmc else { return }
        p.stats.fullness = c.hungerHearts * 25; p.stats.strength = c.strengthHearts * 25
        p.stats.weight = min(99,max(1,p.stats.weight)); p.stats.clamp()
    }
    static func mistake(_ p: inout Pet, _ message: String, at date: Date) {
        p.dmc!.stageMistakes += 1; p.stats.mistakes += 1
        p.record("care",message,at: date)
    }
    static func injure(_ p: inout Pet, doses: Int, at date: Date) {
        guard !p.stats.injured else { return }
        p.stats.injured = true; p.stats.injuries += 1
        p.dmc!.stageInjuries += 1; p.dmc!.dosesRemaining = max(1,doses)
        p.dmc!.injuredMinutes = 0
        p.record("injury","需要治疗",at: date)
    }
    static func die(_ state: inout GameState, at date: Date) {
        let i = state.activeIndex
        state.pets[i].life = .dead; state.pets[i].sleeping = false
        state.pets[i].record("death","回归数据，养成记录已保留",at: date)
        state.training = nil
        if state.pet.evolutionHistory.count >= 5 {
            var rng = SeededRandom(seed: state.rng)
            state.dmc!.nextEggTraited = rng.number(100) < 30; state.rng = rng.state
        }
    }
    public static func advance(_ state: inout GameState,to now: Date,database: ContentDatabase) throws -> TimeReport {
        guard now.timeIntervalSince1970.isFinite else { throw GameError.invalidData("时间无效") }
        var report = TimeReport()
        guard now >= state.highWatermark else { report.clockReversed = true; return report }
        let rules = try rules(database)
        let previous = state.highWatermark
        state.highWatermark = now
        let i = state.activeIndex
        if state.pet.life != .alive {
            // Calls retain their remaining grace period while in Cold mode.
            let delta = now.timeIntervalSince(previous)
            if state.pet.life == .frozen {
                if let call = state.pet.dmc?.hungerCall { state.pets[i].dmc!.hungerCall = call.addingTimeInterval(delta) }
                if let call = state.pet.dmc?.strengthCall { state.pets[i].dmc!.strengthCall = call.addingTimeInterval(delta) }
                if let call = state.pet.dmc?.sleepCall { state.pets[i].dmc!.sleepCall = call.addingTimeInterval(delta) }
                if let wake = state.pet.dmc?.awakeUntil { state.pets[i].dmc!.awakeUntil = wake.addingTimeInterval(delta) }
            }
            state.lastTick = now; return report
        }
        if state.pet.isEgg {
            let deadline = state.pet.dmc!.eggStartedAt.addingTimeInterval(Double(rules.hatchSeconds))
            guard now >= deadline else { return report }
            state.pets[i].isEgg = false; state.pets[i].evolutionHistory = ["botamon"]
            state.pets[i].stats.weight = 5; state.pets[i].stats.dp = 0
            state.pets[i].dmc!.hungerCall = deadline; state.pets[i].dmc!.strengthCall = deadline
            state.pets[i].record("hatch","孵化 · 黑球兽",at: deadline)
            state.dex["botamon"] = .raised; state.lastTick = deadline; report.hatchings = 1
        }
        let seconds = now.timeIntervalSince(state.lastTick)
        guard seconds >= 60, seconds < Double(Int.max/2) else { return report }
        let count = Int(seconds/60), cursor = state.lastTick
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: state.homeTimeZone)!
        for minute in 1...count {
            guard state.pet.life == .alive else { break }
            let date = cursor.addingTimeInterval(Double(minute*60))
            var p = state.pet
            let s = try rules.species(p.speciesID)
            p.activeMinutes += 1; p.stageMinutes += 1
            let hour = calendar.component(.hour,from: date)
            let scheduled = s.sleepHour.map { TimeEngine.isSleepHour(hour,sleep: $0,wake: 8) } ?? false
            let wasSleeping = p.sleeping
            let intervalStart = date.addingTimeInterval(-60)
            let intervalHour = calendar.component(.hour,from: intervalStart)
            let intervalSleeping = (s.sleepHour.map { TimeEngine.isSleepHour(intervalHour,sleep: $0,wake: 8) } ?? false) &&
                !(p.dmc!.awakeUntil.map { intervalStart < $0 } ?? false)
            if intervalSleeping {
                p.dmc!.sleepMinutes += 1
                if p.dmc!.sleepMinutes >= 480 { p.stats.dp = p.developerTuning?.maxDP ?? s.maxDP }
            } else { p.dmc!.sleepMinutes = 0 }
            p.sleeping = scheduled && !(p.dmc!.awakeUntil.map { date < $0 } ?? false)
            if p.sleeping {
                if !wasSleeping {
                    p.dmc!.sleepCallIssued = false
                }
                if !p.lightsOff && !p.dmc!.sleepCallIssued {
                    p.dmc!.sleepCall = date; p.dmc!.sleepCallIssued = true
                }
                if p.lightsOff { p.dmc!.sleepCall = nil }
                if let call = p.dmc!.sleepCall, date.timeIntervalSince(call) >= 3600 {
                    mistake(&p,"睡眠呼叫一小时未关灯",at: date); p.dmc!.sleepCall = nil
                }
            } else {
                p.dmc!.sleepCall = nil
                if !scheduled { p.dmc!.sleepCallIssued = false; p.dmc!.awakeUntil = nil }
                if wasSleeping { p.lightsOff = false }
            }
            if !intervalSleeping {
                p.awakeMinutes += 1; p.dmc!.hungerMinutes += 1; p.dmc!.strengthMinutes += 1
                if p.dmc!.hungerMinutes >= s.heartLossMinutes {
                    p.dmc!.hungerMinutes = 0
                    if p.dmc!.overfeedExtraCycle { p.dmc!.overfeedExtraCycle = false }
                    else { p.dmc!.hungerHearts = max(0,p.dmc!.hungerHearts-1); p.dmc!.meatBeyondFull = 0 }
                    if p.dmc!.hungerHearts == 0 && p.dmc!.hungerCall == nil { p.dmc!.hungerCall = date }
                }
                if p.dmc!.strengthMinutes >= s.heartLossMinutes {
                    p.dmc!.strengthMinutes = 0; p.dmc!.strengthHearts = max(0,p.dmc!.strengthHearts-1)
                    if p.dmc!.strengthHearts == 0 && p.dmc!.strengthCall == nil { p.dmc!.strengthCall = date }
                }
                p.dmc!.wasteMinutes += 1
                let interval = p.speciesID == "botamon" ? 3 : p.speciesID == "koromon" ? 60 : 120
                if p.dmc!.wasteMinutes >= interval { p.stats.waste = min(8,p.stats.waste+1); p.dmc!.wasteMinutes = 0 }
            }
            if p.dmc!.hungerHearts > 0 { p.dmc!.hungerCall = nil; p.dmc!.emptyHungerMinutes = 0 }
            else if !intervalSleeping { p.dmc!.emptyHungerMinutes += 1 }
            if p.dmc!.strengthHearts > 0 { p.dmc!.strengthCall = nil; p.dmc!.emptyStrengthMinutes = 0 }
            else if !intervalSleeping { p.dmc!.emptyStrengthMinutes += 1 }
            if let call = p.dmc!.hungerCall, date.timeIntervalSince(call) >= 600 {
                if p.speciesID != "botamon" { mistake(&p,"空腹呼叫十分钟未回应",at: date) }
                p.dmc!.hungerCall = nil
            }
            if let call = p.dmc!.strengthCall, date.timeIntervalSince(call) >= 600 {
                if p.speciesID != "botamon" { mistake(&p,"力量呼叫十分钟未回应",at: date) }
                p.dmc!.strengthCall = nil
            }
            if p.stats.waste >= 8 { injure(&p,doses: s.healDoses,at: date) }
            if p.stats.injured && !intervalSleeping { p.dmc!.injuredMinutes += 1 }
            sync(&p); state.pets[i] = p
            if p.dmc!.stageInjuries >= 15 || p.dmc!.injuredMinutes >= 360 ||
               p.dmc!.emptyHungerMinutes >= 720 || p.dmc!.emptyStrengthMinutes >= 720 {
                die(&state,at: date); report.deaths += 1; continue
            }
            if !p.dmc!.evolutionChecked && s.evolutionMinutes > 0 && p.stageMinutes >= s.evolutionMinutes {
                state.pets[i].dmc!.evolutionChecked = true
                if let route = evolutionCandidate(pet: state.pet,rules: rules) {
                    var rng = SeededRandom(seed: state.rng)
                    let success = !route.probabilistic || rng.number(100) < evolutionChance(winRate: p.stats.winRate)
                    state.rng = rng.state
                    if success {
                        evolve(&state,to: route.target,rules: rules,at: date); report.evolutions += 1
                    }
                }
            }
            let stage = try database.species(state.pet.speciesID).stage
            if state.pet.dmc!.stageMistakes >= 5 &&
                ((state.pet.dmc!.evolutionChecked && stage.order >= Stage.champion.order) ||
                 (stage.order >= Stage.mega.order && state.pet.stageMinutes >= 2880)) {
                die(&state,at: date); report.deaths += 1
            }
        }
        state.lastTick = cursor.addingTimeInterval(Double(count)*60); report.minutes = count
        return report
    }
    public static func evolutionChance(winRate: Double) -> Int {
        winRate >= 0.8 ? 100 : winRate >= 0.6 ? 50 : winRate >= 0.4 ? 25 : 0
    }
    public static func evolutionCandidate(pet p: Pet,rules: DMCV1Rules) -> DMCEvolutionRule? {
        guard let c = p.dmc else { return nil }
        func fits(_ n: Int,_ low: Int,_ high: Int?) -> Bool { n >= low && (high.map { n <= $0 } ?? true) }
        return rules.evolutions.filter { r in
            let battles = ["metalgreymon","mamemon","monzaemon"].contains(p.speciesID) ? c.megaBattleCount : c.perfectBattleCount
            return r.from == p.speciesID && fits(c.stageMistakes,r.minimumMistakes,r.maximumMistakes) &&
                fits(c.stageTrainings,r.minimumTraining,r.maximumTraining) && fits(c.overfeeds,r.minimumOverfeeds,r.maximumOverfeeds) &&
                fits(c.sleepDisturbances,r.minimumSleepDisturbances,r.maximumSleepDisturbances) && battles >= r.minimumBattles
        }.sorted { $0.priority == $1.priority ? $0.id < $1.id : $0.priority > $1.priority }.first
    }
    static func evolve(_ state: inout GameState,to target: String,rules: DMCV1Rules,at date: Date) {
        let i = state.activeIndex, old = state.pet.dmc!, next = rules.roster[target]!
        var care = DMCCareState(eggStartedAt: old.eggStartedAt,traited: old.traited)
        care.hungerHearts = old.hungerHearts; care.strengthHearts = old.strengthHearts
        care.perfectBattleCount = old.perfectBattleCount
        if care.hungerHearts == 0 { care.hungerCall = date }
        if care.strengthHearts == 0 { care.strengthCall = date }
        state.pets[i].dmc = care; state.pets[i].speciesID = target; state.pets[i].stageMinutes = 0
        state.pets[i].developerTuning = nil
        state.pets[i].stats.dp = next.maxDP; state.pets[i].stats.weight = max(next.minimumWeight,state.pet.stats.weight)
        state.pets[i].stats.injured = false; state.pets[i].evolutionHistory.append(target)
        state.pets[i].record("evolution","进化 · \(target)",at: date); state.dex[target] = .raised
        state.training = nil; state.dmc!.trainingChoices = []; state.dmc!.trainingHits = []
        if target == "shinmonzaemon" { state.dmc!.backgrounds.insert("25th-anniversary") }
        sync(&state.pets[i])
    }
    /// Selecting food/training/battle while lights are on wakes a sleeping pet for 10 minutes.
    public static func wake(_ state: inout GameState,at now: Date) throws {
        guard state.pet.life == .alive, !state.pet.isEgg else { throw GameError.cannotAct("请等待孵化或恢复成长") }
        if state.pet.sleeping {
            guard !state.pet.lightsOff else { throw GameError.cannotAct("请先开灯") }
            let i = state.activeIndex
            state.pets[i].sleeping = false; state.pets[i].dmc!.awakeUntil = now.addingTimeInterval(600)
            state.pets[i].dmc!.sleepDisturbances += 1; state.pets[i].dmc!.sleepMinutes = 0
            state.pets[i].dmc!.sleepCall = nil
            state.pets[i].record("wake","睡眠打扰 · 暂时清醒十分钟",at: now)
        }
    }
    public static func perform(_ action: CareAction,state: inout GameState,database: ContentDatabase,at now: Date) throws {
        let rules = try rules(database), i = state.activeIndex
        var result = state
        switch action {
        case .rebirth(let id):
            guard state.pet.life == .dead, id == "dmc-v1-egg" else { throw GameError.cannotAct("仅在伙伴死亡后重新孵化 Ver.1 蛋") }
            try addEgg(&result,at: now)
        case .selectPet:
            throw GameError.cannotAct("档案仅供查看；请通过备份交换恢复另一只伙伴")
        case .freeze(let frozen):
            guard !state.pet.isEgg, state.pet.life != .dead else { throw GameError.cannotAct("当前无法使用 Cold") }
            result.pets[i].life = frozen ? .frozen : .alive
            if frozen { result.pets[i].stats.injured = false; result.pets[i].dmc!.injuredMinutes = 0; result.pets[i].dmc!.dosesRemaining = 0 }
            result.training = nil; result.lastTick = now
            result.pets[i].record("cold",frozen ? "Cold · 暂停成长" : "解除 Cold",at: now)
        case .rest:
            throw GameError.cannotAct("Ver.1 按作息自动入睡；暂停成长请使用 Cold")
        default:
            guard state.pet.life == .alive, !state.pet.isEgg, state.training == nil else { throw GameError.cannotAct("当前无法照顾，请结束训练或恢复成长") }
            switch action {
            case .feed(let id):
                guard ["meat","protein"].contains(id) else { throw GameError.cannotAct("Ver.1 只有肉和蛋白质") }
                try wake(&result,at: now)
                guard !result.pet.stats.injured else { throw GameError.cannotAct("请先治疗") }
                if id == "meat" {
                    let baby = result.pet.speciesID == "botamon"
                    guard result.pet.dmc!.hungerHearts < 4 || (!baby && result.pet.dmc!.meatBeyondFull < 10) else { throw GameError.cannotAct("已经吃饱，拒绝继续进食") }
                    if result.pet.dmc!.hungerHearts < 4 { result.pets[i].dmc!.hungerHearts += 1 }
                    else { result.pets[i].dmc!.meatBeyondFull += 1 }
                    result.pets[i].stats.weight += 1
                    if (baby && result.pet.dmc!.hungerHearts == 4) || result.pet.dmc!.meatBeyondFull == 10 {
                        result.pets[i].dmc!.overfeeds += 1; result.pets[i].dmc!.overfeedExtraCycle = true
                    }
                    result.pets[i].dmc!.hungerCall = nil; result.pets[i].dmc!.emptyHungerMinutes = 0
                } else {
                    result.pets[i].dmc!.strengthHearts = min(4,result.pet.dmc!.strengthHearts+1)
                    result.pets[i].stats.weight += 2; result.pets[i].dmc!.proteinCount += 1
                    if result.pet.dmc!.proteinCount % 4 == 0 {
                        result.pets[i].stats.dp = min(try result.pet.developerTuning?.maxDP ?? rules.species(result.pet.speciesID).maxDP,result.pet.stats.dp+1)
                        result.pets[i].dmc!.proteinOverdoses = min(7,result.pet.dmc!.proteinOverdoses+1)
                    }
                    result.pets[i].dmc!.strengthCall = nil; result.pets[i].dmc!.emptyStrengthMinutes = 0
                }
                result.pets[i].stats.meals += 1; result.pets[i].record("feed",id == "meat" ? "肉" : "蛋白质",at: now)
            case .clean:
                result.pets[i].stats.waste = 0
                result.pets[i].record("clean","冲洗完成",at: now)
            case .medicine:
                guard result.pet.stats.injured else { throw GameError.cannotAct("没有受伤") }
                result.pets[i].dmc!.dosesRemaining = max(0,result.pet.dmc!.dosesRemaining-1)
                if result.pet.dmc!.dosesRemaining == 0 { result.pets[i].stats.injured = false; result.pets[i].dmc!.injuredMinutes = 0 }
                result.pets[i].record("heal",result.pet.stats.injured ? "继续治疗" : "伤势已恢复",at: now)
            case .lights(let off):
                result.pets[i].lightsOff = off
                if off { result.pets[i].dmc!.sleepCall = nil }
            default: break
            }
        }
        sync(&result.pets[result.activeIndex]); state = result
    }
    static func addEgg(_ state: inout GameState,at now: Date) throws {
        guard state.pets.count < 32 else { throw GameError.cannotAct("档案已达32只，请先导出保存") }
        var pet = Pet(speciesID: "botamon",eggID: "dmc-v1-egg")
        pet.dmc = DMCCareState(eggStartedAt: now,traited: state.dmc!.nextEggTraited)
        pet.stats.dp = 0; sync(&pet); pet.record("egg","Ver.1 数码蛋 · 8秒孵化",at: now)
        state.dmc!.nextEggTraited = false; state.pets.append(pet); state.activePetID = pet.id
        state.lastTick = now; state.training = nil
    }
    public static func swapBackup(_ state: inout GameState,at now: Date) throws {
        guard state.deviceID == deviceID, !state.pet.isEgg, state.pet.life != .dead, state.training == nil else { throw GameError.cannotAct("当前无法交换备份") }
        var result = state
        let current = result.activeIndex, backup = result.dmc!.backupPetID, waste = result.pet.stats.waste
        if let backup {
            guard let index = result.pets.firstIndex(where: { $0.id == backup }) else { throw GameError.invalidData("备份伙伴不存在") }
            result.pets[current].life = .frozen
            result.dmc!.backupPetID = result.pets[current].id; result.activePetID = backup
            result.pets[index].life = .alive; result.pets[index].stats.waste = waste
            result.pets[index].dmc!.hungerHearts = 0; result.pets[index].dmc!.strengthHearts = 0
            result.pets[index].dmc!.hungerCall = now; result.pets[index].dmc!.strengthCall = now
            result.pets[index].dmc!.emptyHungerMinutes = 0; result.pets[index].dmc!.emptyStrengthMinutes = 0
            result.pets[index].dmc!.awakeUntil = nil; result.pets[index].dmc!.sleepCall = nil
            sync(&result.pets[index])
        } else {
            result.pets[current].life = .frozen; result.dmc!.backupPetID = result.pet.id
            try addEgg(&result,at: now); result.pets[result.activeIndex].stats.waste = waste
        }
        result.lastTick = now; state = result
    }
    public static func beginTraining(_ state: inout GameState,at now: Date) throws {
        guard state.training == nil else { throw GameError.cannotAct("训练已开始") }
        try wake(&state,at: now)
        guard !state.pet.stats.injured else { throw GameError.cannotAct("请先治疗") }
        state.training = TrainingSession(id: UUID(),petID: state.activePetID,startedAt: now)
        state.dmc!.trainingChoices = []; state.dmc!.trainingHits = []
    }
    @discardableResult public static func train(_ state: inout GameState,choice: String,database: ContentDatabase,at now: Date) throws -> Int? {
        guard let session = state.training, session.petID == state.activePetID, ["A","B"].contains(choice),
              state.pet.life == .alive, !state.pet.sleeping, !state.pet.stats.injured,
              state.dmc!.trainingChoices.count < 5 else { throw GameError.cannotAct("训练尚未开始或已失效") }
        let rules = try rules(database), shot = state.dmc!.trainingChoices.count
        let pattern = Array(rules.trainingPatterns[state.dmc!.trainingCycle % 10])
        state.dmc!.trainingChoices.append(choice); state.dmc!.trainingHits.append(String(pattern[shot]) == choice)
        guard state.dmc!.trainingChoices.count == 5 else { return nil }
        let hits = state.dmc!.trainingHits.filter { $0 }.count, i = state.activeIndex
        state.pets[i].dmc!.stageTrainings += 1; state.pets[i].stats.trainingAttempts += 1
        if hits >= 3 {
            state.pets[i].stats.training += 1; state.pets[i].dmc!.strengthHearts = min(4,state.pet.dmc!.strengthHearts+1)
            state.pets[i].dmc!.strengthCall = nil; state.pets[i].dmc!.emptyStrengthMinutes = 0
        }
        state.pets[i].stats.weight = max(try rules.species(state.pet.speciesID).minimumWeight,state.pet.stats.weight-1)
        state.pets[i].record("training","上/下段训练 · 命中\(hits)/5 · \(hits >= 3 ? "成功" : "失败")",at: now)
        state.dmc!.trainingCycle = (state.dmc!.trainingCycle+1)%10; state.training = nil; sync(&state.pets[i])
        return hits
    }
    public static func hitChance(power: Int,enemyPower: Int,attribute: Attribute,enemyAttribute: Attribute) -> Int {
        let m = BattleEngine.multiplier(attacker: attribute,defender: enemyAttribute)
        let adjustment = m > 1 ? 5 : m < 1 ? -5 : 0
        return max(0,min(100,power*100/max(1,power+enemyPower)+adjustment))
    }
    public static func quest(_ state: inout GameState,areaID: Int,database: ContentDatabase,at now: Date) throws -> DMCQuestResult {
        let rules = try rules(database)
        guard let area = rules.areas.first(where: { $0.id == areaID }),
              areaID == 1 || state.dmc!.clearedAreas.contains(areaID-1) else { throw GameError.cannotAct("请先通关前一区域") }
        var result = state
        try wake(&result,at: now)
        let species = try database.species(result.pet.speciesID), i = result.activeIndex
        guard species.stage.order >= Stage.rookie.order, result.pet.stats.dp > 0,
              !result.pet.stats.injured, result.training == nil else { throw GameError.cannotAct("Quest需要成长期以上、无伤且DP至少1") }
        let s = try rules.species(species.id)
        let bonus: Int = species.stage == .rookie ? 5 : species.stage == .champion ? 8 : species.stage == .ultimate ? 15 : 25
        let power = (result.pet.developerTuning?.power ?? s.power) + (result.pet.dmc!.strengthHearts == 4 ? bonus : 0) + (result.pet.dmc!.traited ? bonus : 0)
        result.pets[i].stats.dp -= 1; result.pets[i].stats.weight = max(s.minimumWeight,result.pet.stats.weight-6)
        var rng = SeededRandom(seed: result.rng), records: [BattleRecord] = []
        for enemy in area.opponents {
            let chance = hitChance(power: power,enemyPower: enemy.power,attribute: species.attribute,enemyAttribute: enemy.attribute)
            var hits = 0, misses = 0, log: [String] = []
            while hits < 3 && misses < 3 {
                if rng.number(100) < chance { hits += 1; log.append("攻击命中 · \(hits)：\(misses)") }
                else { misses += 1; log.append("受到攻击 · \(hits)：\(misses)") }
            }
            let won = hits == 3
            result.pets[i].stats.battles += 1; result.pets[i].dmc!.stageBattles += 1
            if species.stage == .rookie || species.stage == .champion { result.pets[i].dmc!.perfectBattleCount += 1 }
            if species.stage == .ultimate { result.pets[i].dmc!.megaBattleCount += 1 }
            if won { result.pets[i].stats.wins += 1 }
            let injuryChance = won ? 20 : min(80,10+result.pet.dmc!.proteinOverdoses*10)
            if rng.number(100) < injuryChance { injure(&result.pets[i],doses: s.healDoses,at: now) }
            result.dex[enemy.speciesID] = max(result.dex[enemy.speciesID] ?? .encountered,.encountered)
            // hpRemaining is retained only for the legacy record format. Quest UI uses hit marks.
            let record = BattleRecord(id: UUID(),date: now,opponent: enemy.speciesID,won: won,turns: hits+misses,hpRemaining: 0,log: log)
            records.append(record); result.battles.append(record)
            result.pets[i].record("quest","\(area.name) · \(enemy.speciesID) · \(won ? "胜利" : "败北")",at: now)
            if !won { break }
        }
        result.rng = rng.state
        let cleared = records.count == area.opponents.count && records.allSatisfy(\.won)
        var reward: String?
        if cleared {
            result.dmc!.clearedAreas.insert(areaID)
            if let bg = area.backgroundReward, result.dmc!.backgrounds.insert(bg).inserted { reward = bg }
        }
        if result.pet.dmc!.stageInjuries >= 15 { die(&result,at: now) }
        if result.battles.count > 100 { result.battles.removeFirst(result.battles.count-100) }
        sync(&result.pets[i]); state = result
        return DMCQuestResult(area: area,records: records,cleared: cleared,backgroundUnlocked: reward)
    }
}
