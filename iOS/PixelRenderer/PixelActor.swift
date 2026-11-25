import SpriteKit
import DigitalWorldCore

/// Shared atlas handling for the home pet and both fighters; PNG bytes stay unchanged.
enum PixelAtlas {
    static let manifest = try? SpriteLibrary.manifest()
    private static var tiles: [String:[SKTexture]] = [:]
    static let lcdShader = SKShader(source: """
        void main() {
            vec4 pixel = texture2D(u_texture, v_tex_coord);
            vec4 shaded = SKDefaultShading();
            float luminance = dot(pixel.rgb, vec3(0.299, 0.587, 0.114));
            float level = floor(luminance * 3.0 + 0.5) / 3.0;
            vec3 lcd = mix(vec3(0.19, 0.27, 0.19), vec3(0.66, 0.73, 0.52), level);
            gl_FragColor = vec4(lcd, 1.0) * shaded.a;
        }
        """)
    static func textures(_ id: String) -> [SKTexture] {
        if let cached = tiles[id] { return cached }
        guard let sheet = manifest?.sprites[id], let bytes = try? SpriteLibrary.imageData(id: id),
              let image = UIImage(data: bytes) else { return [] }
        let atlas = SKTexture(image: image); atlas.filteringMode = .nearest
        let result = (0..<(sheet.columns*sheet.rows)).compactMap { i -> SKTexture? in
            guard let r = try? sheet.region(frame: i) else { return nil }
            let texture = SKTexture(rect: CGRect(x: r.x,y: r.y,width: r.width,height: r.height),in: atlas)
            texture.filteringMode = .nearest; return texture
        }
        tiles[id] = result; return result
    }
}

final class PixelActor: SKSpriteNode {
    private(set) var speciesID = ""
    private(set) var pose = "idle"
    var frameIndex: Int { PixelAtlas.textures(speciesID).firstIndex { $0 === texture } ?? -1 }
    var facingRight: Bool { xScale < 0 }
    init(size: CGFloat) {
        super.init(texture: nil,color: .white,size: CGSize(width: size,height: size))
        colorBlendFactor = 0
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    func use(_ id: String,mode: DisplayMode) { speciesID = id; shader = mode == .lcd ? PixelAtlas.lcdShader : nil; color = .white }
    func face(right: Bool) { xScale = right ? -abs(xScale) : abs(xScale) }
    func play(_ action: String,animated: Bool = true) {
        removeAction(forKey: "pose"); pose = action
        guard let sheet = PixelAtlas.manifest?.sprites[speciesID],
              let animation = sheet.animations[action] ?? sheet.animations["idle"] else { texture = nil; return }
        let all = PixelAtlas.textures(speciesID)
        let frames = animation.frameIndices.compactMap { all.indices.contains($0) ? all[$0] : nil }
        texture = frames.first
        if animated && frames.count > 1 {
            run(.repeatForever(.animate(with: frames,timePerFrame: animation.frameSeconds)),withKey: "pose")
        }
    }
}
