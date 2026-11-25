import Foundation

public struct DMCSpeciesRule: Codable, Sendable {
    public var id: String
    public var minimumWeight: Int
    public var sleepHour: Int?
    public var heartLossMinutes: Int
    public var maxDP: Int
    public var healDoses: Int
    public var power: Int
    public var evolutionMinutes: Int
}

public struct DMCEvolutionRule: Codable, Identifiable, Sendable {
    public var id: String
    public var from: String
    public var target: String
    public var priority: Int
    public var minimumMistakes: Int
    public var maximumMistakes: Int?
    public var minimumTraining: Int
    public var maximumTraining: Int?
    public var minimumOverfeeds: Int
    public var maximumOverfeeds: Int?
    public var minimumSleepDisturbances: Int
    public var maximumSleepDisturbances: Int?
    public var minimumBattles: Int
    public var probabilistic: Bool
    public var summary: String
}

public struct DMCQuestOpponent: Codable, Sendable {
    public var speciesID: String
    public var attribute: Attribute
    public var power: Int
}
public struct DMCQuestArea: Codable, Identifiable, Sendable {
    public var id: Int
    public var name: String
    public var opponents: [DMCQuestOpponent]
    public var backgroundReward: String?
}

public struct DMCV1Rules: Codable, Sendable {
    public var version: Int
    public var deviceID: String
    public var manualURL: String
    public var referenceURLs: [String]
    public var verificationNotes: [String]
    public var hatchSeconds: Int
    public var trainingPatterns: [String]
    public var roster: [String: DMCSpeciesRule]
    public var evolutions: [DMCEvolutionRule]
    public var areas: [DMCQuestArea]

    public static func bundled() throws -> Self {
        guard let url = Bundle.module.url(forResource: "dmc-ver1",withExtension: "json") else {
            throw GameError.invalidData("缺少 COLOR Ver.1 规则")
        }
        return try JSONDecoder().decode(Self.self,from: Data(contentsOf: url))
    }
    public func species(_ id: String) throws -> DMCSpeciesRule {
        guard let result = roster[id] else { throw GameError.invalidData("不属于 COLOR Ver.1：\(id)") }
        return result
    }
    public func validate(database: ContentDatabase) throws {
        guard version > 0, hatchSeconds == 8, trainingPatterns.count == 10,
              trainingPatterns.allSatisfy({ $0.count == 5 && $0.allSatisfy { $0 == "A" || $0 == "B" } }),
              areas.map(\.id) == Array(1...8) else { throw GameError.invalidData("COLOR Ver.1 规则结构错误") }
        for (id,s) in roster {
            _ = try database.species(id)
            guard id == s.id, s.heartLossMinutes > 0, s.maxDP >= 0, s.power >= 0,
                  (1...99).contains(s.minimumWeight), s.evolutionMinutes >= 0 else {
                throw GameError.invalidData("COLOR Ver.1 角色参数错误")
            }
        }
        for rule in evolutions { _ = try species(rule.from); _ = try species(rule.target) }
        for area in areas {
            guard (3...5).contains(area.opponents.count) else { throw GameError.invalidData("Quest 敌人数量错误") }
            for enemy in area.opponents { _ = try species(enemy.speciesID) }
        }
    }
}

public struct DMCCareState: Codable, Equatable, Sendable {
    public var eggStartedAt: Date
    public var hungerHearts = 0
    public var strengthHearts = 0
    public var stageTrainings = 0
    public var stageMistakes = 0
    public var stageBattles = 0
    public var perfectBattleCount = 0
    public var megaBattleCount = 0
    public var overfeeds = 0
    public var meatBeyondFull = 0
    public var overfeedExtraCycle = false
    public var sleepDisturbances = 0
    public var proteinCount = 0
    public var proteinOverdoses = 0
    public var stageInjuries = 0
    public var dosesRemaining = 0
    public var hungerMinutes = 0
    public var strengthMinutes = 0
    public var wasteMinutes = 0
    public var emptyHungerMinutes = 0
    public var emptyStrengthMinutes = 0
    public var injuredMinutes = 0
    public var sleepMinutes = 0
    public var hungerCall: Date?
    public var strengthCall: Date?
    public var sleepCall: Date?
    public var sleepCallIssued = false
    public var awakeUntil: Date?
    public var evolutionChecked = false
    public var traited = false
    public var effortHearts: Int { min(4,stageTrainings/4) }
    public init(eggStartedAt: Date,traited: Bool = false) {
        self.eggStartedAt = eggStartedAt; self.traited = traited
    }
}

public struct DMCDeviceState: Codable, Equatable, Sendable {
    public var trainingCycle = 0
    public var trainingChoices: [String] = []
    public var trainingHits: [Bool] = []
    public var backupPetID: UUID?
    public var clearedAreas: Set<Int> = []
    public var backgrounds: Set<String> = ["grasslands","office"]
    public var selectedBackground = "grasslands"
    public var nextEggTraited = false
    public init() {}
}

public struct DMCQuestResult: Sendable {
    public var area: DMCQuestArea
    public var records: [BattleRecord]
    public var cleared: Bool
    public var backgroundUnlocked: String?
    public var playerSpeciesID: String
}
