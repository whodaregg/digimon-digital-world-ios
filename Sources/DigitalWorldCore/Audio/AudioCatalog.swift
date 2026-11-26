import Foundation

public enum AudioEvent: String, Codable, CaseIterable, Identifiable, Sendable {
    case powerOn, powerOff, keyPress, menuSelect, confirm, cancel, error
    case eggAppears, eggHatches, birth, attention, hunger, feeding, eatMeat, eatPill, drinkWater, full, refuseFood
    case waste, cleanWaste, bath, sickness, treatment, recovered, sleep, lightsOff, wake
    case trainingStart, trainingSuccess, trainingFailure, battleStart, attack, specialAttack, finishingMove
    case injured, guardHit, evade, victory, defeat, encounter, bossAppears, mapMove, itemObtained, missionComplete
    case evolution, superEvolution, ultimateEvolution, armorEvolution, jogress, spiritEvolution, xAntibodyEvolution
    case doubleSpiritEvolution, hyperSpiritEvolution, matrixEvolution, cardSlash, digisoul
    case burstMode, digiXros, deEvolution, death, rebirth, deviceUnlocked, digidexCollected, specialEvent
    case backgroundMusic, battleMusic, evolutionTrigger, deviceEvolutionResponse, evolutionMusic, evolutionVoice
    case formReveal, evolutionComplete
    public var id: String { rawValue }

    public static let evolutionTypes: [Self] = [
        .evolution, .superEvolution, .ultimateEvolution, .armorEvolution, .jogress, .spiritEvolution,
        .xAntibodyEvolution, .burstMode, .digiXros, .deEvolution, .matrixEvolution, .doubleSpiritEvolution, .hyperSpiritEvolution
    ]

    public var battleCue: Bool {
        switch self {
        case .battleStart, .attack, .specialAttack, .finishingMove, .injured, .guardHit, .evade,
             .victory, .defeat, .encounter, .bossAppears: return true
        default: return false
        }
    }

    public var dramatic: Bool {
        switch self {
        case .specialAttack, .finishingMove, .bossAppears, .specialEvent, .battleMusic, .evolutionTrigger,
             .evolutionMusic, .evolutionVoice, .formReveal, .evolutionComplete, .evolution, .superEvolution,
             .ultimateEvolution, .armorEvolution, .jogress, .spiritEvolution, .xAntibodyEvolution, .burstMode,
             .digiXros, .deEvolution, .matrixEvolution, .doubleSpiritEvolution, .hyperSpiritEvolution, .cardSlash, .digisoul: return true
        default: return false
        }
    }
}

public enum AudioMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic, anime, hybrid
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .classic: return "Classic Device Mode"
        case .anime: return "Original Anime Mode"
        case .hybrid: return "Hybrid Mode"
        }
    }
}

public enum AudioCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case deviceSFX = "ORIGINAL DEVICE SFX"
    case animeSFX = "ORIGINAL ANIME SFX"
    case animeBGM = "ORIGINAL ANIME BGM"
    case characterVoice = "ORIGINAL CHARACTER VOICE"
    case limitedEdition = "LIMITED EDITION AUDIO"
    public var id: String { rawValue }
}

public enum AudioSeries: String, Codable, CaseIterable, Identifiable, Sendable {
    case adventure, adventure02, tamers, frontier, savers, xrosWars
    public var id: String { rawValue }
}

public enum AudioChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case bgm, sfx, voice, evolutionMusic, battle
    public var id: String { rawValue }
}

public struct AudioContext: Equatable, Sendable {
    public var deviceID: String
    public var series: AudioSeries?
    public var speciesID: String?
    public var evolutionType: AudioEvent?
    public var stage: String?
    public init(deviceID: String, series: AudioSeries? = nil, speciesID: String? = nil,
                evolutionType: AudioEvent? = nil, stage: String? = nil) {
        self.deviceID = deviceID
        self.series = series
        self.speciesID = speciesID
        self.evolutionType = evolutionType
        self.stage = stage
    }
}

public struct AudioMapping: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var event: AudioEvent
    public var category: AudioCategory
    public var deviceID: String?
    public var series: AudioSeries?
    public var speciesID: String?
    public var evolutionType: AudioEvent?
    public var stage: String?
    public var source: String
    public var authorization: String
    public var channel: AudioChannel
    public var loop: Bool = false
    public var volume: Double = 1
    public var priority: Int = 0

    public init(event: AudioEvent, category: AudioCategory, source: String, authorization: String, channel: AudioChannel) {
        self.event = event
        self.category = category
        self.source = source
        self.authorization = authorization
        self.channel = channel
    }

    private static let validEvolutionTypes = Set(AudioEvent.evolutionTypes)

    public var isValid: Bool {
        guard (0...1).contains(volume), (0...100).contains(priority),
              source.count <= 512, authorization.count <= 512,
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !authorization.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              evolutionType.map({ Self.validEvolutionTypes.contains($0) }) ?? true else { return false }
        if category == .deviceSFX || category == .limitedEdition {
            guard let deviceID, !deviceID.isEmpty, series == nil else { return false }
        } else if series == nil { return false }
        if event == .backgroundMusic && channel != .bgm { return false }
        if event == .battleMusic && channel != .bgm { return false }
        if event == .evolutionMusic && channel != .evolutionMusic { return false }
        if event == .evolutionVoice && channel != .voice { return false }
        if channel == .evolutionMusic && event != .evolutionMusic { return false }
        if channel == .bgm && event != .backgroundMusic && event != .battleMusic { return false }
        if category == .characterVoice && channel != .voice { return false }
        if category == .animeBGM && channel != .bgm && channel != .evolutionMusic { return false }
        return !loop || channel == .bgm
    }

    public func score(for event: AudioEvent, mode: AudioMode, context: AudioContext) -> Int? {
        guard isValid, self.event == event,
              deviceID == nil || deviceID == context.deviceID,
              series == nil || series == context.series,
              speciesID == nil || speciesID == context.speciesID,
              evolutionType == nil || evolutionType == context.evolutionType,
              stage == nil || stage == context.stage else { return nil }
        let fromDevice = category == .deviceSFX || category == .limitedEdition
        if event == .deviceEvolutionResponse {
            guard fromDevice else { return nil }
        } else {
            switch mode {
            case .classic: guard fromDevice else { return nil }
            case .anime: guard !fromDevice else { return nil }
            case .hybrid: guard fromDevice != event.dramatic else { return nil }
            }
        }
        let constraints = [deviceID != nil, series != nil, speciesID != nil, evolutionType != nil, stage != nil]
        return constraints.filter { $0 }.count * 1000 + (category == .limitedEdition ? 200 : 0) + priority
    }
}
