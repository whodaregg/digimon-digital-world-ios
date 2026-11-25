import SpriteKit
import SwiftUI
import DigitalWorldCore

final class PetScene: SKScene {
    private let pet = SKSpriteNode()
    private var signature = ""
    private var sheetCache: [String: SKTexture] = [:]
    private let manifest = try? SpriteLibrary.manifest()
    private var style: DisplayMode = .lcd
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit; anchorPoint = CGPoint(x: 0.5, y: 0.5)
        pet.size = CGSize(width: 96, height: 96)
        pet.position = CGPoint(x: 0, y: -10); pet.zPosition = 3
        addChild(pet)
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    func configure(species: Species?, egg: Bool, eggPattern: String, life: LifeState, animation: String,
                   mode: DisplayMode, waste: Int, dark: Bool, night: Bool, reduceMotion: Bool) {
        let key = "\(species?.id ?? "")-\(egg)-\(eggPattern)-\(life)-\(animation)-\(mode)-\(waste)-\(dark)-\(night)-\(reduceMotion)"
        guard key != signature else { return }; signature = key; style = mode
        children.filter { $0 != pet }.forEach { $0.removeFromParent() }
        let lcd = mode == .lcd
        let ink = lcd ? UIColor(red: 0.19, green: 0.27, blue: 0.19, alpha: 1) : UIColor(red: 0.49, green: 0.77, blue: 0.60, alpha: 1)
        backgroundColor = lcd ? UIColor(red: dark ? 0.34 : 0.66, green: dark ? 0.43 : 0.73, blue: dark ? 0.32 : 0.52, alpha: 1) :
            (night ? UIColor(red: 0.08, green: 0.15, blue: 0.25, alpha: 1) : UIColor(red: 0.42, green: 0.71, blue: 0.72, alpha: 1))
        func square(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor, z: CGFloat = 0) {
            let n = SKSpriteNode(color: color, size: CGSize(width: w, height: h)); n.position = CGPoint(x: x,y: y); n.zPosition = z; addChild(n)
        }
        for x in stride(from: -160, through: 160, by: 4) {
            for y in stride(from: -100, through: 100, by: 4) {
                if (x+y)%12 == 0 { square(CGFloat(x), CGFloat(y), 1, 1, ink.withAlphaComponent(0.06)) }
            }
        }
        square(0, -67, 320, 3, ink.withAlphaComponent(0.45), z: 1)
        if !lcd {
            for i in 0..<9 {
                let x = CGFloat(-150+i*38)
                square(x, -48, 24, 34, ink.withAlphaComponent(0.30))
                square(x, -29, 16, 8, ink.withAlphaComponent(0.30))
            }
            for i in 0..<5 {
                square(CGFloat(-130+i*65), CGFloat(45+(i%2)*13), 24, 5, UIColor.white.withAlphaComponent(night ? 0.1 : 0.4))
            }
        }
        if night {
            for i in 0..<13 { square(CGFloat((i*47)%300-150),CGFloat(15+(i*31)%70),2,2,ink.withAlphaComponent(0.7)) }
        }
        for i in 0..<min(4,waste) {
            square(CGFloat(70+i*15),-57,10,6,ink,z: 2); square(CGFloat(70+i*15),-52,5,5,ink,z: 2)
        }
        pet.removeAllActions(); pet.removeAllChildren()
        pet.color = ink; pet.colorBlendFactor = lcd ? 1 : 0
        pet.alpha = life == .frozen ? 0.55 : 1
        if egg {
            pet.texture = nil; pet.colorBlendFactor = 0; pet.color = .clear
            for y in 0..<16 {
                for x in 0..<12 {
                    let dx = Double(x)-5.5, dy = Double(y)-8
                    if dx*dx/28+dy*dy/55 < 1 {
                        let spot = eggPattern == "stripes" ? y % 5 < 2 : (x*3+y*7)%13 < 3
                        let tile = SKSpriteNode(color: spot ? ink : (lcd ? ink.withAlphaComponent(0.3) : .white), size: CGSize(width: 4,height: 4))
                        tile.position = CGPoint(x: x*4-24,y: (16-y)*4-32); pet.addChild(tile)
                    }
                }
            }
            if !reduceMotion { pet.run(.repeatForever(.sequence([.rotate(toAngle: 0.08,duration: 0.2),.rotate(toAngle: -0.08,duration: 0.2),.rotate(toAngle: 0,duration: 0.2),.wait(forDuration: 1.4)]))) }
            return
        }
        pet.zRotation = 0
        guard let species, let manifest, let config = manifest.animations[animation] ?? manifest.animations["idle"] else { return }
        let sheet: SKTexture
        if let cached = sheetCache[species.spriteID] { sheet = cached }
        else if let bytes = try? SpriteLibrary.imageData(id: species.spriteID), let uiImage = UIImage(data: bytes) {
            sheet = SKTexture(image: uiImage); sheet.filteringMode = .nearest; sheetCache[species.spriteID] = sheet
        } else { return }
        let textures = (0..<config.frames).map { frame -> SKTexture in
            let rect = CGRect(x: Double(frame)/Double(manifest.columns),
                              y: 1-Double(config.row+1)/Double(manifest.rows),
                              width: 1/Double(manifest.columns),height: 1/Double(manifest.rows))
            let texture = SKTexture(rect: rect, in: sheet); texture.filteringMode = .nearest; return texture
        }
        pet.texture = textures.first
        if !reduceMotion && life != .frozen { pet.run(.repeatForever(.animate(with: textures,timePerFrame: config.frameSeconds)),withKey: "frames") }
        if mode == .advanced && !reduceMotion {
            for i in 0..<7 {
                let n = SKSpriteNode(color: UIColor(red: 0.8,green: 0.95,blue: 0.7,alpha: 0.7),size: CGSize(width: 2,height: 2))
                n.position = CGPoint(x: i*40-140,y: -20+(i*17)%90); n.zPosition = 2; addChild(n)
                n.run(.repeatForever(.sequence([.moveBy(x: 0,y: 8,duration: 1.5),.moveBy(x: 0,y: -8,duration: 1.5)])))
            }
        }
    }
}

struct PetScreen: View {
    @ObservedObject var model: WorldViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = PetScene(size: CGSize(width: 320,height: 200))
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            SpriteView(scene: configured(at: context.date), isPaused: false, preferredFramesPerSecond: 15,
                       options: [.ignoresSiblingOrder])
                .aspectRatio(1.6,contentMode: .fit)
                .accessibilityLabel(model.state?.pet.isEgg == true ? "孵化中的数码蛋" : "像素伙伴 \(model.species?.name ?? "")")
        }
    }
    private func configured(at date: Date) -> PetScene {
        guard let state = model.state else { return scene }
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: state.homeTimeZone) ?? .current
        let hour = c.component(.hour, from: date)
        scene.configure(species: model.species, egg: state.pet.isEgg,
                        eggPattern: (try? model.database?.egg(state.pet.eggID).pattern) ?? "spots", life: state.pet.life,
                        animation: model.animationName, mode: state.settings.display,
                        waste: state.pet.stats.waste, dark: state.pet.lightsOff,
                        night: hour < 7 || hour >= 19, reduceMotion: reduceMotion)
        return scene
    }
}
