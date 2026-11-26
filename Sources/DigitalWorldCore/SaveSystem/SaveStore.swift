import Foundation

public struct LoadedSave: Sendable {
    public var state: GameState
    public var recoveredBackup: Bool
    public var migrated: Bool
}

public struct SaveStore: Sendable {
    public let directory: URL
    public let database: ContentDatabase
    public var primaryURL: URL { directory.appendingPathComponent("world.json") }
    public var backupURL: URL { directory.appendingPathComponent("world.backup.json") }
    public init(directory: URL, database: ContentDatabase) { self.directory = directory; self.database = database }

    private struct Envelope: Codable {
        var format: Int
        var checksum: String
        var payload: Data
    }
    public static func checksum(_ data: Data) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in data { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(format: "%016llx", hash)
    }
    public func encode(_ state: GameState) throws -> Data {
        try database.validateSave(state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payload = try encoder.encode(state)
        let data = try encoder.encode(Envelope(format: 1,checksum: Self.checksum(payload),payload: payload))
        guard data.count <= 16*1024*1024 else { throw GameError.cannotAct("存档达到容量上限，请先导出完整档案；原存档保持原样") }
        return data
    }
    public func decode(_ data: Data) throws -> LoadedSave {
        guard data.count <= 16 * 1024 * 1024 else { throw GameError.saveCorrupt }
        let envelope: Envelope
        do { envelope = try JSONDecoder().decode(Envelope.self, from: data) }
        catch { throw GameError.saveCorrupt }
        guard envelope.format == 1, envelope.checksum == Self.checksum(envelope.payload) else { throw GameError.saveCorrupt }
        guard var object = try JSONSerialization.jsonObject(with: envelope.payload) as? [String: Any],
              let version = object["schemaVersion"] as? Int else { throw GameError.saveCorrupt }
        if version > GameState.currentVersion { throw GameError.futureSave(version) }
        guard version >= 1 else { throw GameError.saveCorrupt }
        // v1 -> v2: the fixed tick cursor becomes the initial wall-clock watermark.
        if version == 1 {
            object["highWatermark"] = object["highWatermark"] ?? object["lastTick"]
        }
        if version <= 4 { object["schemaVersion"] = GameState.currentVersion }
        let migratedData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        var state = try JSONDecoder().decode(GameState.self, from: migratedData)
        try database.validateSave(state)
        let migrated = version < GameState.currentVersion || state.databaseVersion < database.version
        state.databaseVersion = database.version
        return LoadedSave(state: state, recoveredBackup: false, migrated: migrated)
    }
    public func load() throws -> LoadedSave? {
        let fm = FileManager.default
        let primaryExists = fm.fileExists(atPath: primaryURL.path)
        let backupExists = fm.fileExists(atPath: backupURL.path)
        guard primaryExists || backupExists else { return nil }
        if primaryExists {
            do { return try decode(Data(contentsOf: primaryURL)) }
            catch GameError.futureSave(let version) { throw GameError.futureSave(version) }
            catch {
                if backupExists {
                    var recovered = try decode(Data(contentsOf: backupURL))
                    recovered.recoveredBackup = true
                    return recovered
                }
                throw error
            }
        }
        var recovered = try decode(Data(contentsOf: backupURL))
        recovered.recoveredBackup = true
        return recovered
    }
    public func save(_ state: GameState) throws {
        let data = try encode(state)
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if let existing = try? Data(contentsOf: primaryURL) {
            if (try? decode(existing)) != nil {
                try existing.write(to: backupURL, options: .atomic)
            } else {
                // Preserve damaged evidence; never replace a good backup with corrupt bytes.
                let damaged = directory.appendingPathComponent("world.damaged.json")
                if !fm.fileExists(atPath: damaged.path) { try existing.write(to: damaged, options: .atomic) }
            }
        } else if !fm.fileExists(atPath: backupURL.path) {
            try data.write(to: backupURL, options: .atomic)
        }
        try data.write(to: primaryURL, options: .atomic)
    }
}
