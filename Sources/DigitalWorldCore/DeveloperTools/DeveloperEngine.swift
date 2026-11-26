import Foundation

/// Per-pet test overrides; ordinary species data is never rewritten.
public struct DeveloperTuning: Codable, Equatable, Sendable {
    public var power: Int?
    public var maxDP: Int?
    public var battleStats: BaseStats?
    public init() {}
}

public enum DeveloperField: String, CaseIterable, Identifiable, Sendable {
    case activeMinutes, stageMinutes, awakeMinutes, weight, dpCapacity, dp, power
    case hungerHearts, strengthHearts, stageTrainings, stageMistakes, stageBattles
    case perfectBattleCount, megaBattleCount, overfeeds, meatBeyondFull, sleepDisturbances
    case proteinCount, proteinOverdoses, stageInjuries, dosesRemaining
    case hungerMinutes, strengthMinutes, wasteMinutes, emptyHungerMinutes, emptyStrengthMinutes, injuredMinutes, sleepMinutes
    case fullness, strength, happiness, energy, health, stamina, bond, loyalty
    case hp, attack, defense, speed, critical
    case training, trainingAttempts, meals, battles, wins, mistakes, injuries, illnesses, waste
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .activeMinutes: return "年龄（分钟）"
        case .stageMinutes: return "本阶段成长（分钟）"
        case .awakeMinutes: return "累计清醒（分钟）"
        case .weight: return "体重"
        case .dpCapacity: return "DP上限"
        case .dp: return "当前DP"
        case .power: return "战斗力量"
        case .hungerHearts: return "饱食心"
        case .strengthHearts: return "力量心"
        case .stageTrainings: return "本阶段训练（每4次加1努力心）"
        case .stageMistakes: return "本阶段照顾失误"
        case .stageBattles: return "本阶段战斗"
        case .perfectBattleCount: return "完全体进化战斗计数"
        case .megaBattleCount: return "究极体进化战斗计数"
        case .overfeeds: return "满腹次数"
        case .meatBeyondFull: return "满心后的肉"
        case .sleepDisturbances: return "睡眠打扰"
        case .proteinCount: return "蛋白质计数"
        case .proteinOverdoses: return "蛋白质过量等级"
        case .stageInjuries: return "本阶段受伤次数"
        case .dosesRemaining: return "剩余治疗次数"
        case .hungerMinutes: return "饱食下降计时"
        case .strengthMinutes: return "力量下降计时"
        case .wasteMinutes: return "排泄计时"
        case .emptyHungerMinutes: return "持续空腹计时"
        case .emptyStrengthMinutes: return "持续空力量计时"
        case .injuredMinutes: return "伤势持续计时"
        case .sleepMinutes: return "连续睡眠计时"
        case .fullness: return "饱食度"
        case .strength: return "力量值"
        case .happiness: return "幸福"
        case .energy: return "能量"
        case .health: return "健康"
        case .stamina: return "体力"
        case .bond: return "亲密度"
        case .loyalty: return "忠诚度"
        case .hp: return "战斗HP"
        case .attack: return "攻击"
        case .defense: return "防御"
        case .speed: return "速度"
        case .critical: return "暴击率"
        case .training: return "训练成功（通算）"
        case .trainingAttempts: return "训练尝试（通算）"
        case .meals: return "喂食次数"
        case .battles: return "战斗（通算）"
        case .wins: return "胜利（通算）"
        case .mistakes: return "照顾失误（通算）"
        case .injuries: return "受伤（通算）"
        case .illnesses: return "生病（通算）"
        case .waste: return "废物"
        }
    }
    public func range(original: Bool) -> ClosedRange<Int> {
        switch self {
        case .hungerHearts,.strengthHearts: return 0...4
        case .weight: return 1...(original ? 99 : 999)
        case .dp,.dpCapacity: return 0...99
        case .meatBeyondFull: return 0...10
        case .proteinOverdoses: return 0...7
        case .waste: return 0...8
        case .fullness,.strength,.happiness,.energy,.health,.stamina,.bond,.loyalty,.critical: return 0...100
        case .hp,.attack,.defense,.speed: return 1...1_000_000
        default: return 0...1_000_000
        }
    }
    public static func available(original: Bool) -> [Self] {
        allCases.filter { field in
            switch field {
            case .dpCapacity,.power,.hungerHearts,.strengthHearts,.stageTrainings,.stageMistakes,.stageBattles,
                 .perfectBattleCount,.megaBattleCount,.overfeeds,.meatBeyondFull,.sleepDisturbances,.proteinCount,
                 .proteinOverdoses,.stageInjuries,.dosesRemaining,.hungerMinutes,.strengthMinutes,.wasteMinutes,
                 .emptyHungerMinutes,.emptyStrengthMinutes,.injuredMinutes,.sleepMinutes: return original
            case .fullness,.strength,.happiness,.energy,.health,.stamina,.bond,.loyalty,.hp,.attack,.defense,.speed,.critical: return !original
            default: return true
            }
        }
    }
    public func value(pet p: Pet, database: ContentDatabase) throws -> Int {
        guard Self.available(original: p.dmc != nil).contains(self), p.dmc == nil || database.dmcV1 != nil else {
            throw GameError.cannotAct("该机型不使用此数值")
        }
        let c = p.dmc
        let b = try p.developerTuning?.battleStats ?? database.species(p.speciesID).stats
        switch self {
        case .activeMinutes: return p.activeMinutes
        case .stageMinutes: return p.stageMinutes
        case .awakeMinutes: return p.awakeMinutes
        case .weight: return p.stats.weight
        case .dp: return p.stats.dp
        case .dpCapacity: return try p.developerTuning?.maxDP ?? database.colorSpecies(p.speciesID).maxDP
        case .power: return try p.developerTuning?.power ?? database.colorSpecies(p.speciesID).power
        case .hungerHearts: return c!.hungerHearts
        case .strengthHearts: return c!.strengthHearts
        case .stageTrainings: return c!.stageTrainings
        case .stageMistakes: return c!.stageMistakes
        case .stageBattles: return c!.stageBattles
        case .perfectBattleCount: return c!.perfectBattleCount
        case .megaBattleCount: return c!.megaBattleCount
        case .overfeeds: return c!.overfeeds
        case .meatBeyondFull: return c!.meatBeyondFull
        case .sleepDisturbances: return c!.sleepDisturbances
        case .proteinCount: return c!.proteinCount
        case .proteinOverdoses: return c!.proteinOverdoses
        case .stageInjuries: return c!.stageInjuries
        case .dosesRemaining: return c!.dosesRemaining
        case .hungerMinutes: return c!.hungerMinutes
        case .strengthMinutes: return c!.strengthMinutes
        case .wasteMinutes: return c!.wasteMinutes
        case .emptyHungerMinutes: return c!.emptyHungerMinutes
        case .emptyStrengthMinutes: return c!.emptyStrengthMinutes
        case .injuredMinutes: return c!.injuredMinutes
        case .sleepMinutes: return c!.sleepMinutes
        case .fullness: return p.stats.fullness
        case .strength: return p.stats.strength
        case .happiness: return p.stats.happiness
        case .energy: return p.stats.energy
        case .health: return p.stats.health
        case .stamina: return p.stats.stamina
        case .bond: return p.stats.bond
        case .loyalty: return p.stats.loyalty
        case .hp: return b.hp
        case .attack: return b.attack
        case .defense: return b.defense
        case .speed: return b.speed
        case .critical: return b.critical
        case .training: return p.stats.training
        case .trainingAttempts: return p.stats.trainingAttempts
        case .meals: return p.stats.meals
        case .battles: return p.stats.battles
        case .wins: return p.stats.wins
        case .mistakes: return p.stats.mistakes
        case .injuries: return p.stats.injuries
        case .illnesses: return p.stats.illnesses
        case .waste: return p.stats.waste
        }
    }
    fileprivate func set(_ n: Int, pet p: inout Pet, database: ContentDatabase) throws {
        switch self {
        case .activeMinutes: p.activeMinutes = n
        case .stageMinutes: p.stageMinutes = n
        case .awakeMinutes: p.awakeMinutes = n
        case .weight: p.stats.weight = n
        case .dp: p.stats.dp = n
        case .dpCapacity: p.developerTuning!.maxDP = n
        case .power: p.developerTuning!.power = n
        case .hungerHearts: p.dmc!.hungerHearts = n
        case .strengthHearts: p.dmc!.strengthHearts = n
        case .stageTrainings: p.dmc!.stageTrainings = n
        case .stageMistakes: p.dmc!.stageMistakes = n
        case .stageBattles: p.dmc!.stageBattles = n
        case .perfectBattleCount: p.dmc!.perfectBattleCount = n
        case .megaBattleCount: p.dmc!.megaBattleCount = n
        case .overfeeds: p.dmc!.overfeeds = n
        case .meatBeyondFull: p.dmc!.meatBeyondFull = n
        case .sleepDisturbances: p.dmc!.sleepDisturbances = n
        case .proteinCount: p.dmc!.proteinCount = n
        case .proteinOverdoses: p.dmc!.proteinOverdoses = n
        case .stageInjuries: p.dmc!.stageInjuries = n
        case .dosesRemaining: p.dmc!.dosesRemaining = n
        case .hungerMinutes: p.dmc!.hungerMinutes = n
        case .strengthMinutes: p.dmc!.strengthMinutes = n
        case .wasteMinutes: p.dmc!.wasteMinutes = n
        case .emptyHungerMinutes: p.dmc!.emptyHungerMinutes = n
        case .emptyStrengthMinutes: p.dmc!.emptyStrengthMinutes = n
        case .injuredMinutes: p.dmc!.injuredMinutes = n
        case .sleepMinutes: p.dmc!.sleepMinutes = n
        case .fullness: p.stats.fullness = n
        case .strength: p.stats.strength = n
        case .happiness: p.stats.happiness = n
        case .energy: p.stats.energy = n
        case .health: p.stats.health = n
        case .stamina: p.stats.stamina = n
        case .bond: p.stats.bond = n
        case .loyalty: p.stats.loyalty = n
        case .hp,.attack,.defense,.speed,.critical:
            if p.developerTuning!.battleStats == nil { p.developerTuning!.battleStats = try database.species(p.speciesID).stats }
            switch self {
            case .hp: p.developerTuning!.battleStats!.hp = n
            case .attack: p.developerTuning!.battleStats!.attack = n
            case .defense: p.developerTuning!.battleStats!.defense = n
            case .speed: p.developerTuning!.battleStats!.speed = n
            default: p.developerTuning!.battleStats!.critical = n
            }
        case .training: p.stats.training = n
        case .trainingAttempts: p.stats.trainingAttempts = n
        case .meals: p.stats.meals = n
        case .battles: p.stats.battles = n
        case .wins: p.stats.wins = n
        case .mistakes: p.stats.mistakes = n
        case .injuries: p.stats.injuries = n
        case .illnesses: p.stats.illnesses = n
        case .waste: p.stats.waste = n
        }
    }
}

public struct DeveloperPetEdit: Sendable {
    public var petID: UUID
    public var speciesID: String
    public var values: [DeveloperField:Int] = [:]
    public var life: LifeState?
    public var injured: Bool?
    public var sick: Bool?
    public var lightsOff: Bool?
    public var traited: Bool?
    public var evolutionChecked: Bool?
    public init(pet: Pet) { petID = pet.id; speciesID = pet.speciesID }
}

public enum DeveloperAction: Sendable {
    case selectSpecies(String), grantItem(String,Int), edit(DeveloperPetEdit)
}

public enum DeveloperEngine {
    public static func itemCatalog(database: ContentDatabase, state: GameState) -> [String:String] {
        var result = Dictionary(uniqueKeysWithValues: database.foods.map { ($0.id,$0.name) })
        for s in database.species { for route in s.evolutions { if let item = route.requiredItem { result[item] = item == "evolution-chip" ? "进化芯片" : item } } }
        for item in state.inventory.keys where result[item] == nil { result[item] = item }
        return result
    }
    public static func perform(_ action: DeveloperAction,state: inout GameState,database: ContentDatabase,at now: Date) throws {
        guard now >= state.highWatermark, now.timeIntervalSince1970.isFinite else { throw GameError.cannotAct("请恢复正确设备时间") }
        var next = state
        try TimeEngine.advance(&next,to: now,database: database)
        let i = next.activeIndex, original = DeviceRegistry.isColor(next.deviceID)
        switch action {
        case .selectSpecies(let id):
            let species = try database.species(id)
            var p = next.pet
            p.speciesID = id; p.isEgg = false; p.life = .alive; p.stageMinutes = 0
            p.sleeping = false; p.manualRest = false; p.lightsOff = false
            p.neglectMinutes = 0; p.sleepNeglectMinutes = 0; p.dirtyMinutes = 0
            p.stats = CareStats(); p.developerTuning = DeveloperTuning()
            if original {
                let rule = try database.colorRules(for: next.deviceID)!.species(id)
                p.dmc = DMCCareState(eggStartedAt: now); p.dmc!.hungerHearts = 4; p.dmc!.strengthHearts = 4
                p.dmc!.awakeUntil = now.addingTimeInterval(600)
                p.stats.weight = rule.minimumWeight; p.stats.dp = rule.maxDP
                DMCV1Engine.sync(&p)
            } else { p.dmc = nil; p.stats.dp = min(99,species.stats.dp) }
            if p.evolutionHistory.last != id { p.evolutionHistory.append(id) }
            p.record("developer","开发测试 · 指定角色：\(species.nameSC)",at: now)
            next.pets[i] = p; next.dex[id] = .raised
        case .grantItem(let id,let count):
            guard !id.isEmpty, id.count <= 64, id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }),
                  (1...999999).contains(count), next.inventory[id,default: 0] <= 999999-count else {
                throw GameError.cannotAct("道具ID须为字母、数字、短横线或下划线；数量须在1～999999内且不超过库存上限")
            }
            next.inventory[id,default: 0] += count
            next.pets[i].record("developer","开发测试 · 道具 \(id) ＋\(count)",at: now)
        case .edit(let edit):
            guard edit.petID == next.pet.id, edit.speciesID == next.pet.speciesID else { throw GameError.cannotAct("伙伴已变化，请重新载入当前数值") }
            var p = next.pet
            if p.developerTuning == nil { p.developerTuning = DeveloperTuning() }
            let available = Set(DeveloperField.available(original: original))
            for (field,value) in edit.values {
                guard available.contains(field), field.range(original: original).contains(value) else { throw GameError.cannotAct("\(field.title)超出允许范围") }
                try field.set(value,pet: &p,database: database)
            }
            if let life = edit.life { p.life = life }
            if let injured = edit.injured { p.stats.injured = injured }
            if let sick = edit.sick { p.stats.sick = sick }
            if let off = edit.lightsOff { p.lightsOff = off }
            if original {
                if let traited = edit.traited { p.dmc!.traited = traited }
                if let checked = edit.evolutionChecked { p.dmc!.evolutionChecked = checked }
                if p.dmc!.hungerHearts > 0 { p.dmc!.hungerCall = nil }
                else if p.dmc!.hungerCall == nil { p.dmc!.hungerCall = now }
                if p.dmc!.strengthHearts > 0 { p.dmc!.strengthCall = nil }
                else if p.dmc!.strengthCall == nil { p.dmc!.strengthCall = now }
                if !p.stats.injured { p.dmc!.injuredMinutes = 0; p.dmc!.dosesRemaining = 0 }
                DMCV1Engine.sync(&p)
            }
            p.record("developer","开发测试 · 修改数值",at: now); next.pets[i] = p
        }
        next.training = nil
        next.dmc?.trainingChoices = []; next.dmc?.trainingHits = []
        next.developerModifiedAt = now
        try database.validateSave(next)
        state = next
    }
}
