import Foundation

public enum PlayStyle: String, Codable, CaseIterable, Sendable {
    case classic, enhanced, sandbox
    public var isFormal: Bool { self != .sandbox }
}
public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case simplified = "zh-Hans", traditional = "zh-Hant", english = "en", japanese = "ja"
    public var title: String {
        switch self { case .simplified: return "简体中文"; case .traditional: return "繁體中文"; case .english: return "English"; case .japanese: return "日本語" }
    }
}
public struct DevicePresentationSettings: Codable, Equatable, Sendable {
    public var touchMode = true
    public var volume: Double = 0.55
    public var contrast: Double = 1
    public var brightness: Double = 1
    public var shell = "brown"
    public var language: AppLanguage = .simplified
    public init() {}
}
public extension Settings {
    var presentation: DevicePresentationSettings { interface ?? DevicePresentationSettings() }
}
public extension GameState {
    var playStyle: PlayStyle { sessionStyle ?? .enhanced }
    var contributesToCollection: Bool { playStyle.isFormal && developerModifiedAt == nil && mode == .original }
}

public struct SpeciesAppearance: Codable, Equatable, Sendable {
    public var speciesID: String
    public var date: Date
    public init(_ speciesID: String,at date: Date) { self.speciesID = speciesID; self.date = date }
}
public struct DigidexEntry: Equatable, Identifiable, Sendable {
    public var id: String
    public var discovery: Discovery
    public var firstObtained: Date?
    public var obtainedCount: Int
    public var deviceIDs: Set<String>
}
public enum CollectionManager {
    /// Unique pet identities prevent reopening or toggling modes from granting another obtain.
    public static func entries(in worlds: [GameState]) -> [DigidexEntry] {
        var result: [String:DigidexEntry] = [:], obtained: [String:Set<UUID>] = [:]
        for world in worlds where world.contributesToCollection {
            for (id,discovery) in world.dex {
                var entry = result[id] ?? .init(id: id,discovery: discovery,firstObtained: nil,obtainedCount: 0,deviceIDs: [])
                entry.discovery = max(entry.discovery,discovery); entry.deviceIDs.insert(world.deviceID); result[id] = entry
            }
            for pet in world.pets {
                for id in Set(pet.evolutionHistory) where !pet.isEgg || pet.evolutionHistory.count > 0 {
                    obtained[id,default: []].insert(pet.id)
                    var entry = result[id] ?? .init(id: id,discovery: .raised,firstObtained: nil,obtainedCount: 0,deviceIDs: [])
                    entry.discovery = .raised; entry.deviceIDs.insert(world.deviceID)
                    if let date = pet.appearances?.filter({ $0.speciesID == id }).map(\.date).min() {
                        entry.firstObtained = min(entry.firstObtained ?? date,date)
                    }
                    result[id] = entry
                }
            }
            for life in world.lifecycles ?? [] {
                for id in life.forms {
                    obtained[id,default: []].insert(life.id)
                    var entry = result[id] ?? .init(id: id,discovery: .raised,firstObtained: nil,obtainedCount: 0,deviceIDs: [])
                    entry.discovery = .raised; entry.deviceIDs.insert(world.deviceID); result[id] = entry
                }
                for appearance in life.appearances {
                    obtained[appearance.speciesID,default: []].insert(life.id)
                    var entry = result[appearance.speciesID] ?? .init(id: appearance.speciesID,discovery: .raised,firstObtained: nil,obtainedCount: 0,deviceIDs: [])
                    entry.firstObtained = min(entry.firstObtained ?? appearance.date,appearance.date)
                    entry.deviceIDs.insert(world.deviceID); result[appearance.speciesID] = entry
                }
            }
        }
        for id in result.keys { result[id]!.obtainedCount = obtained[id]?.count ?? 0 }
        return result.values.sorted { $0.id < $1.id }
    }
}
public struct LifecycleRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var deviceID: String
    public var finalSpeciesID: String
    public var startedAt: Date
    public var reason: String?
    public var endedAt: Date
    public var activeMinutes: Int
    public var battles: Int
    public var wins: Int
    public var forms: [String]
    public var appearances: [SpeciesAppearance]
    public var history: [JournalEvent]
}
public enum LifecycleManager {
    public static func capture(_ state: inout GameState) {
        var records = state.lifecycles ?? []
        for pet in state.pets where pet.life == .dead && !records.contains(where: { $0.id == pet.id }) {
            guard let end = pet.history.last(where: { $0.kind == "death" })?.date else { continue }
            records.append(.init(id: pet.id,deviceID: state.deviceID,finalSpeciesID: pet.speciesID,
                                 startedAt: pet.dmc?.eggStartedAt ?? pet.history.first?.date ?? end,reason: "death",endedAt: end,
                                 activeMinutes: pet.activeMinutes,battles: pet.stats.battles,wins: pet.stats.wins,
                                 forms: pet.evolutionHistory,appearances: pet.appearances ?? [],history: pet.history))
        }
        if !records.isEmpty { state.lifecycles = records }
    }
    public static func archiveBeforeReset(_ state: inout GameState,at date: Date) {
        capture(&state)
        var records = state.lifecycles ?? []
        for pet in state.pets where !records.contains(where: { $0.id == pet.id }) {
            records.append(.init(id: pet.id,deviceID: state.deviceID,finalSpeciesID: pet.speciesID,
                                 startedAt: pet.dmc?.eggStartedAt ?? pet.history.first?.date ?? date,reason: "reset",endedAt: date,
                                 activeMinutes: pet.activeMinutes,battles: pet.stats.battles,wins: pet.stats.wins,
                                 forms: pet.evolutionHistory,appearances: pet.appearances ?? [],history: pet.history))
        }
        state.lifecycles = records
    }
    public static func makeRoom(_ state: inout GameState) throws {
        capture(&state)
        let archived = Set((state.lifecycles ?? []).map(\.id))
        if state.pets.count >= 32,let index = state.pets.firstIndex(where: { $0.life == .dead && archived.contains($0.id) }) {
            state.pets.remove(at: index)
        }
        guard state.pets.count < 32 else { throw GameError.cannotAct("当前伙伴档位已满，请先处理正在成长或Cold中的伙伴") }
    }
}

public struct DeviceSlot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var deviceID: String
    public var style: PlayStyle
    public var createdAt: Date
    public var lastOpenedAt: Date
}
public struct DeviceLibraryIndex: Codable, Equatable, Sendable {
    public var version = 1
    public var activeID: UUID?
    public var slots: [DeviceSlot] = []
    public init() {}
}
/// Each physical-device instance owns an independent SaveStore, including its backups.
public struct DeviceLibraryStore: Sendable {
    public let directory: URL
    public let database: ContentDatabase
    public init(directory: URL,database: ContentDatabase) { self.directory = directory; self.database = database }
    public func store(for slot: DeviceSlot) -> SaveStore {
        SaveStore(directory: directory.appendingPathComponent("devices/"+slot.id.uuidString),database: database)
    }
    public func loadIndex() throws -> DeviceLibraryIndex {
        let path = directory.appendingPathComponent("devices.json"), backup = directory.appendingPathComponent("devices.backup.json")
        guard FileManager.default.fileExists(atPath: path.path) || FileManager.default.fileExists(atPath: backup.path) else { return .init() }
        func decode(_ url: URL) throws -> DeviceLibraryIndex {
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder().decode(LibraryEnvelope.self,from: data)
            guard data.count <= 1_048_576,SaveStore.checksum(envelope.payload) == envelope.checksum else { throw GameError.saveCorrupt }
            let index = try JSONDecoder().decode(DeviceLibraryIndex.self,from: envelope.payload)
            guard index.version == 1,index.slots.count <= 128,Set(index.slots.map(\.id)).count == index.slots.count,
                  index.activeID == nil || index.slots.contains(where: { $0.id == index.activeID }) else { throw GameError.saveCorrupt }
            for slot in index.slots { _ = try database.device(slot.deviceID) }
            return index
        }
        do { return try decode(path) } catch {
            if let recovered = try? decode(backup) { return recovered }; throw error
        }
    }
    public func saveIndex(_ index: DeviceLibraryIndex) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(index), path = directory.appendingPathComponent("devices.json")
        let envelope = try encoder.encode(LibraryEnvelope(checksum: SaveStore.checksum(payload),payload: payload))
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        if let existing = try? Data(contentsOf: path) {
            // Only a valid primary may replace the recovery copy.
            if let e = try? JSONDecoder().decode(LibraryEnvelope.self,from: existing),SaveStore.checksum(e.payload) == e.checksum {
                try existing.write(to: directory.appendingPathComponent("devices.backup.json"),options: .atomic)
            } else {
                try existing.write(to: directory.appendingPathComponent("devices.damaged.json"),options: .atomic)
            }
        }
        try envelope.write(to: path,options: .atomic)
    }
    public func add(_ state: GameState,to index: inout DeviceLibraryIndex,at now: Date) throws -> DeviceSlot {
        guard index.slots.count < 128 else { throw GameError.cannotAct("设备收藏档位已满") }
        let slot = DeviceSlot(id: UUID(),deviceID: state.deviceID,style: state.playStyle,createdAt: now,lastOpenedAt: now)
        try store(for: slot).save(state)
        var candidate = index; candidate.slots.append(slot); candidate.activeID = slot.id
        try saveIndex(candidate); index = candidate; return slot
    }
    public func worlds(in index: DeviceLibraryIndex) throws -> [GameState] {
        try index.slots.map { slot in
            guard let save = try store(for: slot).load() else { throw GameError.invalidData("设备档案缺失，已保留其他存档") }
            guard save.state.deviceID == slot.deviceID,save.state.playStyle.isFormal == slot.style.isFormal else { throw GameError.invalidData("设备档案与索引不一致") }
            return save.state
        }
    }
    private struct LibraryEnvelope: Codable { var checksum: String; var payload: Data }
}
