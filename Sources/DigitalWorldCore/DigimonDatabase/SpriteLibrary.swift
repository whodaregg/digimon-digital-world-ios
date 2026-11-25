import Foundation

public struct SpriteAnimation: Codable, Sendable {
    public var row: Int
    public var frames: Int
    public var frameSeconds: Double
}
public struct SpriteManifest: Codable, Sendable {
    public var tileSize: Int
    public var columns: Int
    public var rows: Int
    public var artStatus: String
    public var animations: [String: SpriteAnimation]
}
public enum SpriteLibrary {
    public static func manifest() throws -> SpriteManifest {
        guard let url = Bundle.module.url(forResource: "sprites", withExtension: "json") else {
            throw GameError.invalidData("缺少像素动画配置")
        }
        return try JSONDecoder().decode(SpriteManifest.self, from: Data(contentsOf: url))
    }
    public static func imageData(id: String) throws -> Data {
        guard let url = Bundle.module.url(forResource: id, withExtension: "png") else {
            throw GameError.invalidData("缺少像素素材：\(id)")
        }
        return try Data(contentsOf: url)
    }
}
