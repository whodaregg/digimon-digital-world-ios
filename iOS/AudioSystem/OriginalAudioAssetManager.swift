import AVFoundation
import Combine
import CryptoKit
import DigitalWorldCore
import Foundation

struct OriginalAudioAsset: Codable, Identifiable, Equatable {
    var mapping: AudioMapping
    let originalFilename: String
    let format: String
    let duration: Double
    let sha256: String
    var id: UUID { mapping.id }
    var storageName: String { "\(sha256).\(format)" }
}

struct OriginalAudioManifest: Codable {
    var version = 1
    var assets: [OriginalAudioAsset] = []
}

struct DeviceAudioPreferences: Codable, Equatable {
    var mode: AudioMode = .hybrid
    var series: AudioSeries?
    var respectSilentSwitch = true
    var volumes: [AudioChannel: Double] = [:]

    func volume(_ channel: AudioChannel) -> Double {
        volumes[channel] ?? (channel == .bgm ? 0.45 : 0.75)
    }
}

enum AudioImportError: LocalizedError {
    case invalidMapping, invalidFile, missingManifest, missingFile, checksum, capacity
    var errorDescription: String? {
        switch self {
        case .invalidMapping: return "请填写适用机型或动漫世代、来源和授权说明，并选择有效的播放频道。"
        case .invalidFile: return "无法读取音频。支持 WAV、M4A、MP3、AAC 和 CAF。"
        case .missingManifest: return "ZIP 缺少有效的 manifest.json。"
        case .missingFile: return "音频包缺少清单指定的文件。"
        case .checksum: return "文件 SHA-256 与清单不一致。"
        case .capacity: return "音频文件或资源库超过容量限制。"
        }
    }
}

@MainActor
final class OriginalAudioAssetManager: ObservableObject {
    @Published private(set) var manifest = OriginalAudioManifest()
    @Published private(set) var available: Set<String> = []
    @Published private(set) var preferences: [String: DeviceAudioPreferences] = [:]
    @Published private(set) var loadingError: String?
    private let directory: URL
    private let defaults: UserDefaults
    private let preferenceKey = "originalAudio.preferences.v1"
    private static let maxLibraryBytes = 512 * 1024 * 1024
    private static let formats: Set<String> = ["wav", "m4a", "mp3", "aac", "caf"]

    private struct Pack: Decodable {
        struct Entry: Decodable {
            let filename: String
            let mapping: AudioMapping
            let sha256: String
        }
        let version: Int
        let assets: [Entry]
    }

    init(directory: URL, defaults: UserDefaults = .standard) {
        self.directory = directory
        self.defaults = defaults
        if let data = defaults.data(forKey: preferenceKey),
           let values = try? JSONDecoder().decode([String: DeviceAudioPreferences].self, from: data) {
            preferences = values
        }
        if FileManager.default.fileExists(atPath: manifestURL.path) {
            do {
                let data = try Self.read(manifestURL, limit: 4 * 1024 * 1024)
                let stored = try JSONDecoder().decode(OriginalAudioManifest.self, from: data)
                guard stored.version == 1, stored.assets.count <= 2048,
                      Set(stored.assets.map(\.id)).count == stored.assets.count,
                      stored.assets.allSatisfy({ $0.mapping.isValid && Self.isHash($0.sha256) && Self.formats.contains($0.format) })
                else { throw AudioImportError.invalidMapping }
                manifest = stored
                scan(verifyHashes: false)
            } catch { loadingError = error.localizedDescription }
        }
    }

    private var manifestURL: URL { directory.appendingPathComponent("manifest.json") }
    func settings(for device: String) -> DeviceAudioPreferences { preferences[device] ?? .init() }

    func update(_ device: String, _ edit: (inout DeviceAudioPreferences) -> Void) {
        var value = settings(for: device)
        edit(&value)
        value.volumes = value.volumes.mapValues { $0.isFinite ? min(1, max(0, $0)) : 0 }
        preferences[device] = value
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: preferenceKey) }
    }

    nonisolated static func read(_ url: URL, limit: Int) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= limit else { throw AudioImportError.capacity }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard !data.isEmpty, data.count <= limit else { throw AudioImportError.capacity }
        return data
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private static func isHash(_ hash: String) -> Bool {
        hash.count == 64 && hash.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    func file(for asset: OriginalAudioAsset) -> URL { directory.appendingPathComponent(asset.storageName) }

    func scan(verifyHashes: Bool = true) {
        var checked: [String: Bool] = [:]
        for asset in manifest.assets where checked[asset.storageName] == nil {
            let url = file(for: asset)
            if verifyHashes {
                checked[asset.storageName] = (try? Self.read(url, limit: AudioZIP.maxFileBytes))
                    .map { Self.hash($0) == asset.sha256 } ?? false
            } else {
                checked[asset.storageName] = FileManager.default.fileExists(atPath: url.path)
            }
        }
        available = Set(checked.compactMap { $0.value ? $0.key : nil })
    }

    func resolve(_ event: AudioEvent, context: AudioContext) -> OriginalAudioAsset? {
        let mode = settings(for: context.deviceID).mode
        let candidates = manifest.assets.compactMap { asset -> (OriginalAudioAsset, Int)? in
            guard available.contains(asset.storageName),
                  let score = asset.mapping.score(for: event, mode: mode, context: context) else { return nil }
            return (asset, score)
        }
        return candidates.max {
            if $0.1 == $1.1 { return $0.0.id.uuidString > $1.0.id.uuidString }
            return $0.1 < $1.1
        }?.0
    }

    func selectedFile(_ url: URL, mapping: AudioMapping, replacing: UUID? = nil) throws -> Int {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Self.read(url, limit: AudioZIP.maxFileBytes)
        return try install([(url.lastPathComponent, mapping, data)], replacing: replacing)
    }

    func importPack(_ url: URL) async throws -> Int {
        let files = try await Task.detached(priority: .userInitiated) {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Self.read(url, limit: AudioZIP.maxArchiveBytes)
            return try AudioZIP.unpack(data)
        }.value
        guard let data = files["manifest.json"], data.count <= 1024 * 1024,
              let pack = try? JSONDecoder().decode(Pack.self, from: data),
              pack.version == 1, !pack.assets.isEmpty, pack.assets.count <= 255 else { throw AudioImportError.missingManifest }
        let entries = try pack.assets.map { entry -> (String, AudioMapping, Data) in
            guard let bytes = files[entry.filename] else { throw AudioImportError.missingFile }
            guard Self.hash(bytes) == entry.sha256.lowercased() else { throw AudioImportError.checksum }
            return (entry.filename, entry.mapping, bytes)
        }
        return try install(entries, replacing: nil)
    }

    private func install(_ entries: [(String, AudioMapping, Data)], replacing: UUID?) throws -> Int {
        if let loadingError { throw GameError.invalidData(loadingError) }
        var candidate = manifest
        if let replacing { candidate.assets.removeAll { $0.id == replacing } }
        guard candidate.assets.count + entries.count <= 2048 else { throw AudioImportError.capacity }
        let fm = FileManager.default
        var bytesByName: [String: Data] = [:]
        var duplicateCount = 0
        var hashes = Set(manifest.assets.map(\.sha256))
        for (name, originalMapping, bytes) in entries {
            var mapping = originalMapping
            mapping.id = replacing ?? UUID()
            guard mapping.isValid else { throw AudioImportError.invalidMapping }
            let format = URL(fileURLWithPath: name).pathExtension.lowercased()
            guard Self.formats.contains(format),
                  let probe = try? AVAudioPlayer(data: bytes, fileTypeHint: format == "aac" ? "public.aac-audio" : nil),
                  probe.duration.isFinite, probe.duration > 0, probe.duration <= 1800 else { throw AudioImportError.invalidFile }
            let hash = Self.hash(bytes)
            if !hashes.insert(hash).inserted { duplicateCount += 1 }
            let asset = OriginalAudioAsset(mapping: mapping, originalFilename: name, format: format, duration: probe.duration, sha256: hash)
            candidate.assets.append(asset)
            bytesByName[asset.storageName] = bytes
        }
        let uniqueFiles = Set(candidate.assets.map(\.storageName))
        let total = uniqueFiles.reduce(0) { sum, name in
            sum + (bytesByName[name]?.count ??
                (try? directory.appendingPathComponent(name).resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        guard total <= Self.maxLibraryBytes else { throw AudioImportError.capacity }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        var newFiles: [URL] = []
        do {
            for (name, bytes) in bytesByName {
                let url = directory.appendingPathComponent(name)
                let exists = fm.fileExists(atPath: url.path)
                if exists, (try? Self.read(url, limit: AudioZIP.maxFileBytes)) == bytes { continue }
                try bytes.write(to: url, options: .atomic)
                if !exists { newFiles.append(url) }
            }
            try save(candidate)
        } catch {
            for url in newFiles { try? fm.removeItem(at: url) }
            throw error
        }
        return duplicateCount
    }

    func remove(_ id: UUID) throws {
        var candidate = manifest
        candidate.assets.removeAll { $0.id == id }
        try save(candidate)
    }

    private func save(_ candidate: OriginalAudioManifest) throws {
        try JSONEncoder().encode(candidate).write(to: manifestURL, options: .atomic)
        let obsolete = Set(manifest.assets.map(\.storageName)).subtracting(candidate.assets.map(\.storageName))
        manifest = candidate
        for name in obsolete { try? FileManager.default.removeItem(at: directory.appendingPathComponent(name)) }
        scan(verifyHashes: false)
    }
}
