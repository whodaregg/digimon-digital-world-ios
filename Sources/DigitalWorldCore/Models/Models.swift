import Foundation

public enum GameMode: String, Codable, CaseIterable, Sendable { case original, ultimate }
public enum DisplayMode: String, Codable, CaseIterable, Sendable { case lcd, color, advanced }
public enum Stage: String, Codable, CaseIterable, Sendable {
    case egg, baby1, baby2, rookie, champion, ultimate, mega, ultra
    public var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
public enum Attribute: String, Codable, CaseIterable, Sendable { case vaccine, data, virus, free, unknown }
public enum LifeState: String, Codable, Sendable { case alive, frozen, dead }
public enum Discovery: Int, Codable, Comparable, Sendable {
    case encountered = 1, raised = 2
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

public struct BaseStats: Codable, Equatable, Sendable {
    public var hp: Int
    public var attack: Int
    public var defense: Int
    public var speed: Int
    public var critical: Int
    public var stamina: Int
    public var dp: Int
}

public struct EvolutionRule: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var target: String
    public var priority: Int
    public var stageMinutes: Int
    public var minimumTraining: Int
    public var minimumBattles: Int
    public var minimumWinRate: Double
    public var maximumMistakes: Int?
    public var minimumMistakes: Int
    public var minimumHealth: Int
    public var minimumWeight: Int
    public var maximumWeight: Int
    public var minimumBond: Int
    public var requiredItem: String?
    public var provenance: String
}

public struct Species: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var nameSC: String
    public var nameTC: String
    public var nameJP: String
    public var stage: Stage
    public var attribute: Attribute
    public var type: String
    public var family: [String]
    public var generation: String
    public var firstAppearance: String?
    public var devices: [String]
    public var stats: BaseStats
    public var specialMove: String
    public var effect: String
    public var rarity: String
    public var sleepHour: Int
    public var wakeHour: Int
    public var lifespanMinutes: Int
    public var spriteID: String
    public var artStatus: String
    public var referenceURL: String?
    public var verifiedFields: [String]
    public var balanceProvenance: String
    public var evolutions: [EvolutionRule]
}

public struct DeviceRule: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var enabled: Bool
    public var verifiedOriginal: Bool
    public var mode: GameMode
    public var notes: String
    public var hungerEveryMinutes: Int
    public var strengthEveryMinutes: Int
    public var wasteEveryMinutes: Int
    public var careGraceMinutes: Int
    public var freezeSupported: Bool
    public var manualRestSupported: Bool
    public var foods: [String]
    public var eggs: [String]
}

public struct Egg: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var hatchMinutes: Int
    public var species: String
    public var pattern: String
    public var requiredRaised: Int
}

public struct Food: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var fullness: Int
    public var strength: Int
    public var happiness: Int
    public var energy: Int
    public var health: Int
    public var weight: Int
}

public struct CareStats: Codable, Equatable, Sendable {
    /// 0 = starving, 100 = full. UI labels use fullness rather than ambiguous hunger.
    public var fullness = 80
    public var strength = 30
    public var happiness = 75
    public var energy = 100
    public var health = 100
    public var weight = 5
    public var stamina = 100
    public var dp = 10
    public var bond = 0
    public var loyalty = 0
    public var training = 0
    public var trainingAttempts = 0
    public var meals = 0
    public var battles = 0
    public var wins = 0
    public var mistakes = 0
    public var injuries = 0
    public var illnesses = 0
    public var waste = 0
    public var sick = false
    public var injured = false
    public var winRate: Double { battles == 0 ? 0 : Double(wins) / Double(battles) }
    public mutating func clamp() {
        fullness = bounded(fullness); strength = bounded(strength); happiness = bounded(happiness)
        energy = bounded(energy); health = bounded(health); stamina = bounded(stamina)
        bond = bounded(bond); loyalty = bounded(loyalty); weight = min(999, max(1, weight))
        dp = min(99, max(0, dp)); waste = min(8, max(0, waste))
    }
    private func bounded(_ x: Int) -> Int { min(100, max(0, x)) }
}

public struct JournalEvent: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var kind: String
    public var message: String
    public init(date: Date, kind: String, message: String) {
        // Deterministic engine output, including identifiers, across batching/replay.
        let key = "\(date.timeIntervalSince1970):\(kind):\(message)"
        let bytes = Array(key.utf8)
        var a: UInt64 = 14695981039346656037
        for byte in bytes { a = (a ^ UInt64(byte)) &* 1099511628211 }
        let hex = String(format: "%016llx%016llx", a, a &* 6364136223846793005)
        let chars = Array(hex)
        let string = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(chars[$0]) }.joined(separator: "-")
        id = UUID(uuidString: string)!
        self.date = date; self.kind = kind; self.message = message
    }
}

public struct Pet: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var speciesID: String
    public var eggID: String
    public var life: LifeState = .alive
    public var isEgg = true
    public var activeMinutes = 0
    public var stageMinutes = 0
    public var awakeMinutes = 0
    public var sleeping = false
    public var manualRest = false
    public var lightsOff = false
    public var neglectMinutes = 0
    public var sleepNeglectMinutes = 0
    public var dirtyMinutes = 0
    public var stats = CareStats()
    public var history: [JournalEvent] = []
    public var evolutionHistory: [String] = []
    public var personality = "Curious"
    public init(id: UUID = UUID(), speciesID: String, eggID: String) {
        self.id = id; self.speciesID = speciesID; self.eggID = eggID
    }
    public mutating func record(_ kind: String, _ message: String, at date: Date) {
        history.append(JournalEvent(date: date, kind: kind, message: message))
        if history.count > 300 { history.removeFirst(history.count - 300) }
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var display: DisplayMode = .lcd
    public var sound = true
    public var haptics = true
    public var notifications = false
    public var quietStart = 22
    public var quietEnd = 8
}

public struct AdventureState: Codable, Equatable, Sendable {
    public var mapID = "signal-garden"
    public var x = 1
    public var y = 1
    public var collected: Set<String> = []
    public var steps = 0
    public var questComplete = false
}

public struct TrainingSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var petID: UUID
    public var startedAt: Date
    public var taps: [Double] = []
}

public struct BattleRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var opponent: String
    public var won: Bool
    public var turns: Int
    public var hpRemaining: Int
    public var log: [String]
}

public struct GameState: Codable, Equatable, Sendable {
    public static let currentVersion = 2
    public var schemaVersion = Self.currentVersion
    public var databaseVersion: Int
    public var deviceID: String
    public var mode: GameMode
    public var homeTimeZone: String
    /// Fixed simulation cursor. Fractional minutes remain unconsumed.
    public var lastTick: Date
    /// Highest observed wall clock, persisted even between simulation ticks.
    public var highWatermark: Date
    public var pets: [Pet]
    public var activePetID: UUID
    public var dex: [String: Discovery] = [:]
    public var inventory: [String: Int] = [:]
    public var settings = Settings()
    public var adventure = AdventureState()
    public var training: TrainingSession?
    public var battles: [BattleRecord] = []
    public var rng: UInt64 = 0xD1617A1
    public var activeIndex: Int { pets.firstIndex { $0.id == activePetID } ?? 0 }
    public var pet: Pet { pets[activeIndex] }

    public init(databaseVersion: Int, deviceID: String, mode: GameMode, timeZone: String, now: Date, pet: Pet) {
        self.databaseVersion = databaseVersion; self.deviceID = deviceID; self.mode = mode
        homeTimeZone = timeZone; lastTick = now; highWatermark = now; pets = [pet]; activePetID = pet.id
    }
}

public enum GameError: Error, LocalizedError, Equatable {
    case invalidData(String), unavailable(String), cannotAct(String), saveCorrupt, futureSave(Int)
    public var errorDescription: String? {
        switch self {
        case .invalidData(let x), .unavailable(let x), .cannotAct(let x): return x
        case .saveCorrupt: return "存档校验失败。原文件已保留，请恢复备份。"
        case .futureSave(let v): return "存档版本 \(v) 高于当前版本，请先更新游戏。"
        }
    }
}
