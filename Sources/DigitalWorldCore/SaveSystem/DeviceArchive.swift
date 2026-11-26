import Foundation

/// A portable, immutable snapshot. Import creates new slots and never overwrites a live device.
public struct DeviceArchive: Codable, Sendable {
    public struct Entry: Codable, Sendable {
        public var slot: DeviceSlot
        public var save: Data
    }
    public var version: Int = 1
    public var id: UUID
    public var createdAt: Date
    public var activeID: UUID?
    public var entries: [Entry]
    private struct Envelope: Codable { var checksum: String; var payload: Data }
    public static let maximumBytes = 128 * 1024 * 1024

    public static func capture(index: DeviceLibraryIndex,library: DeviceLibraryStore,at date: Date) throws -> Self {
        let entries = try index.slots.map { slot -> Entry in
            guard let saved = try library.store(for: slot).load() else { throw GameError.invalidData("设备档案缺失，无法创建完整备份") }
            guard saved.state.deviceID == slot.deviceID,saved.state.playStyle.isFormal == slot.style.isFormal else { throw GameError.saveCorrupt }
            return Entry(slot: slot,save: try library.store(for: slot).encode(saved.state))
        }
        return .init(id: UUID(),createdAt: date,activeID: index.activeID,entries: entries)
    }
    public func encode() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(self)
        let result = try encoder.encode(Envelope(checksum: SaveStore.checksum(payload),payload: payload))
        guard result.count <= Self.maximumBytes else { throw GameError.cannotAct("设备合集超过备份容量上限，请分别导出设备") }
        return result
    }
    public static func decode(_ data: Data,library: DeviceLibraryStore) throws -> Self {
        guard data.count <= maximumBytes else { throw GameError.saveCorrupt }
        let envelope = try JSONDecoder().decode(Envelope.self,from: data)
        guard SaveStore.checksum(envelope.payload) == envelope.checksum else { throw GameError.saveCorrupt }
        let archive = try JSONDecoder().decode(Self.self,from: envelope.payload)
        guard archive.version == 1,archive.createdAt.timeIntervalSince1970.isFinite,
              (1...128).contains(archive.entries.count),
              Set(archive.entries.map { $0.slot.id }).count == archive.entries.count,
              archive.activeID == nil || archive.entries.contains(where: { $0.slot.id == archive.activeID }) else { throw GameError.saveCorrupt }
        for entry in archive.entries {
            let game = try library.store(for: entry.slot).decode(entry.save).state
            guard game.deviceID == entry.slot.deviceID,game.playStyle.isFormal == entry.slot.style.isFormal else { throw GameError.saveCorrupt }
            if let source = entry.slot.sourceSlotID {
                guard !entry.slot.style.isFormal,archive.entries.contains(where: { $0.slot.id == source && $0.slot.style.isFormal && $0.slot.deviceID == entry.slot.deviceID }) else { throw GameError.saveCorrupt }
            }
        }
        return archive
    }
    /// Stage every validated save before publishing the index. Partial writes are rolled back.
    public func restore(library: DeviceLibraryStore,index: inout DeviceLibraryIndex,at date: Date) throws -> UUID? {
        let validated = try Self.decode(encode(),library: library)
        guard index.slots.count + entries.count <= 128 else { throw GameError.cannotAct("设备收藏档位不足，未覆盖现有设备") }
        let mapping = Dictionary(uniqueKeysWithValues: validated.entries.map { ($0.slot.id,UUID()) })
        var candidate = index
        var staged: [DeviceSlot] = []
        do {
            for entry in validated.entries {
                var slot = entry.slot
                slot.id = mapping[entry.slot.id]!
                slot.sourceSlotID = entry.slot.sourceSlotID.flatMap { mapping[$0] }
                slot.lastOpenedAt = date
                let game = try library.store(for: entry.slot).decode(entry.save).state
                staged.append(slot)
                try library.store(for: slot).save(game)
                candidate.slots.append(slot)
            }
            let selected = validated.activeID.flatMap { mapping[$0] } ?? staged.first?.id
            candidate.activeID = index.activeID ?? selected
            try library.saveIndex(candidate)
            index = candidate
            return selected
        } catch {
            for slot in staged { try? FileManager.default.removeItem(at: library.store(for: slot).directory) }
            throw error
        }
    }
}
