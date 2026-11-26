import Foundation

public struct SpriteAnimation: Codable, Sendable {
    public var frameIndices: [Int]
    public var frameSeconds: Double
}
public struct SpriteSheet: Codable, Sendable {
    public var tileSize: Int
    public var columns: Int
    public var rows: Int
    public var animations: [String: SpriteAnimation]
    public var fallbackActions: [String]
    public func region(frame: Int) throws -> SpriteRegion {
        guard frame >= 0, frame < columns * rows else { throw GameError.invalidData("动画帧越界") }
        return SpriteRegion(x: Double(frame % columns) / Double(columns),
                            y: 1 - Double(frame / columns + 1) / Double(rows),
                            width: 1 / Double(columns), height: 1 / Double(rows))
    }
}
public struct SpriteRegion: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
}
public struct SpriteManifest: Codable, Sendable {
    public var schemaVersion: Int
    public var artStatus: String
    public var sprites: [String: SpriteSheet]
    public func validate() throws {
        guard schemaVersion == 2, !sprites.isEmpty else { throw GameError.invalidData("像素图集版本无效") }
        for sheet in sprites.values {
            guard sheet.tileSize > 0, sheet.columns > 0, sheet.rows > 0,
                  sheet.animations["idle"] != nil else { throw GameError.invalidData("像素图集结构无效") }
            for animation in sheet.animations.values {
                guard !animation.frameIndices.isEmpty, animation.frameSeconds > 0 else {
                    throw GameError.invalidData("动画配置无效")
                }
                for frame in animation.frameIndices { _ = try sheet.region(frame: frame) }
            }
        }
    }
}
public enum SpriteLibrary {
    private struct Source: Decodable { var files: [String:File] }
    private struct File: Decodable { var availableFrameIndices: [Int] }
    private static let originals: [String:Set<Int>] = {
        guard let url = Bundle.module.url(forResource: "sprite-sources",withExtension: "json"),
              let bytes = try? Data(contentsOf: url),let source = try? JSONDecoder().decode(Source.self,from: bytes) else { return [:] }
        return source.files.mapValues { Set($0.availableFrameIndices) }
    }()
    public static func availableFrames(id: String) -> Set<Int> { originals[id] ?? [] }

    public static func manifest() throws -> SpriteManifest {
        guard let url = Bundle.module.url(forResource: "sprites", withExtension: "json") else {
            throw GameError.invalidData("缺少像素动画配置")
        }
        let value = try JSONDecoder().decode(SpriteManifest.self, from: Data(contentsOf: url))
        try value.validate()
        return value
    }
    public static func imageData(id: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: id, withExtension: "png") else {
            throw GameError.invalidData("缺少像素素材：\(id)")
        }
        return try Data(contentsOf: url)
    }
}
