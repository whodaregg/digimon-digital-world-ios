import SpriteKit
import SwiftUI
import DigitalWorldCore

final class PetScene: SKScene {
    private let pet = PixelActor(size: 192)
    private var signature = ""
    private var roaming = false
    private var ambientElapsed: Double = 0
    private var ambientOrigin: Double = 0
    private var previousFrame: TimeInterval?
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit; anchorPoint = CGPoint(x: 0.5, y: 0.5)
        pet.position = CGPoint(x: 0, y: 6); pet.zPosition = 3
        addChild(pet)
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    func configure(species: Species?, egg: Bool, eggPattern: String, life: LifeState, animation: String,
                   mode: DisplayMode, waste: Int, dark: Bool, night: Bool, reduceMotion: Bool, background: String) {
        let previousID = pet.speciesID
        let key = "\(species?.id ?? "")-\(egg)-\(eggPattern)-\(life)-\(animation)-\(mode)-\(waste)-\(dark)-\(night)-\(reduceMotion)-\(background)"
        guard key != signature else { return }; signature = key
        children.filter { $0 != pet }.forEach { $0.removeFromParent() }
        let lcd = mode == .lcd
        let dimScene = night || dark
        let ink = lcd ? UIColor(red: 0.19, green: 0.27, blue: 0.19, alpha: 1) : UIColor(red: 0.49, green: 0.77, blue: 0.60, alpha: 1)
        backgroundColor = lcd ? UIColor(red: dark ? 0.34 : 0.66, green: dark ? 0.43 : 0.73, blue: dark ? 0.32 : 0.52, alpha: 1) :
            (dimScene ? UIColor(red: 0.08, green: 0.15, blue: 0.29, alpha: 1) : UIColor(red: 0.35, green: 0.69, blue: 0.91, alpha: 1))
        func square(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor, z: CGFloat = 0) {
            let n = SKSpriteNode(color: color, size: CGSize(width: w, height: h)); n.position = CGPoint(x: x,y: y); n.zPosition = z; addChild(n)
        }
        if lcd {
            for x in stride(from: -160, through: 160, by: 4) {
                for y in stride(from: -120, through: 120, by: 4) {
                    if (x+y)%12 == 0 { square(CGFloat(x), CGFloat(y), 1, 1, ink.withAlphaComponent(0.06)) }
                }
            }
        }
        if !lcd {
            let mountain = dimScene ? UIColor(red: 0.16,green: 0.23,blue: 0.38,alpha: 1) : UIColor(red: 0.37,green: 0.51,blue: 0.69,alpha: 1)
            let leaves = dimScene ? UIColor(red: 0.08,green: 0.27,blue: 0.26,alpha: 1) : UIColor(red: 0.13,green: 0.47,blue: 0.29,alpha: 1)
            let grass = dimScene ? UIColor(red: 0.17,green: 0.35,blue: 0.28,alpha: 1) : UIColor(red: 0.42,green: 0.66,blue: 0.25,alpha: 1)
            for i in 0..<6 {
                let x = CGFloat(-160+i*65)
                square(x,-36,70,48,mountain)
                square(x,-7,42,16,mountain)
                square(x,5,18,8,mountain)
            }
            for i in 0..<9 {
                let x = CGFloat(-150+i*38)
                square(x,-46,30,36,leaves)
                square(x,-24,18,12,leaves)
            }
            square(0,-94,320,54,grass,z: 1)
            square(0,-68,320,4,dimScene ? ink : UIColor(red: 0.68,green: 0.84,blue: 0.39,alpha: 1),z: 1)
            square(0,-91,120,14,dimScene ? UIColor(red: 0.26,green: 0.32,blue: 0.28,alpha: 1) : UIColor(red: 0.75,green: 0.64,blue: 0.41,alpha: 1),z: 1)
            for i in 0..<5 {
                let x = CGFloat(-130+i*65), y = CGFloat(45+(i%2)*13)
                square(x,y,32,6,UIColor.white.withAlphaComponent(dimScene ? 0.15 : 0.75))
                square(x-5,y+5,14,4,UIColor.white.withAlphaComponent(dimScene ? 0.15 : 0.75))
            }
            let light = dimScene ? UIColor(red: 0.91,green: 0.93,blue: 0.74,alpha: 1) : UIColor(red: 1,green: 0.86,blue: 0.42,alpha: 1)
            square(120,67,16,24,light); square(120,67,24,16,light)
        } else {
            square(0,-67,320,3,ink.withAlphaComponent(0.45),z: 1)
        }
        // Original screen themes are represented by new pixel scenery; character PNGs stay untouched.
        if background != "grasslands" {
            let paper = lcd ? UIColor(red: 0.66,green: 0.73,blue: 0.52,alpha: 1) :
                (dimScene ? UIColor(red: 0.09,green: 0.16,blue: 0.24,alpha: 1) : UIColor(red: 0.80,green: 0.88,blue: 0.91,alpha: 1))
            square(0,0,320,240,paper,z: 1.1)
            if background == "office" {
                for x in [-100,80] {
                    square(CGFloat(x),30,65,55,ink.withAlphaComponent(0.35),z: 1.2)
                    square(CGFloat(x),30,54,44,paper,z: 1.3)
                    square(CGFloat(x),30,3,44,ink.withAlphaComponent(0.35),z: 1.4)
                }
                square(0,-70,320,4,ink.withAlphaComponent(0.5),z: 1.4)
                square(-110,-55,60,6,ink,z: 1.4); square(-132,-68,4,24,ink,z: 1.4)
            } else if background == "grid" {
                for x in stride(from: -160,through: 160,by: 16) { square(CGFloat(x),0,1,200,ink.withAlphaComponent(0.25),z: 1.3) }
                for y in stride(from: -96,through: 96,by: 16) { square(0,CGFloat(y),320,1,ink.withAlphaComponent(0.25),z: 1.3) }
            } else {
                for i in 0..<14 { square(CGFloat(i*26-160),CGFloat((i*31)%170-85),12,12,ink.withAlphaComponent(0.2),z: 1.3) }
                let label = SKLabelNode(fontNamed: "Menlo-Bold")
                label.text = background == "25th-anniversary" ? "25th ANNIVERSARY" : background == "box-art" ? "DIGITAL MONSTER" : "COLOR"
                label.fontSize = 15; label.fontColor = ink; label.position = CGPoint(x: 0,y: 60); label.zPosition = 1.5; addChild(label)
            }
        }
        if dimScene {
            for i in 0..<13 { square(CGFloat((i*47)%300-150),CGFloat(15+(i*31)%70),2,2,(lcd ? ink : .white).withAlphaComponent(0.7)) }
        }
        for i in 0..<min(4,waste) {
            square(CGFloat(70+i*15),-57,10,6,ink,z: 2); square(CGFloat(70+i*15),-52,5,5,ink,z: 2)
        }
        roaming = false; ambientElapsed = 0; ambientOrigin = Double(pet.position.x)
        pet.removeAllActions(); pet.removeAllChildren()
        pet.color = ink; pet.colorBlendFactor = 0
        pet.shader = lcd ? PixelAtlas.lcdShader : nil
        pet.zRotation = 0; pet.xScale = 1
        pet.position.x = min(64,max(-64,pet.position.x))
        pet.alpha = life == .frozen ? 0.55 : (dark && !lcd ? 0.7 : 1)
        if egg {
            pet.clear()
            pet.position = CGPoint(x: 0,y: -10)
            pet.texture = nil; pet.colorBlendFactor = 0; pet.color = .clear
            for y in 0..<16 {
                for x in 0..<12 {
                    let dx = Double(x)-5.5, dy = Double(y)-8
                    if dx*dx/28+dy*dy/55 < 1 {
                        let spot = eggPattern == "stripes" ? y % 5 < 2 : (x*3+y*7)%13 < 3
                        let shell = lcd ? ink.withAlphaComponent(0.3) : UIColor(red: 1,green: 0.96,blue: 0.83,alpha: 1)
                        let spots = lcd ? ink : UIColor(red: eggPattern == "stripes" ? 0.91 : 0.26,green: 0.49,blue: 0.76,alpha: 1)
                        let tile = SKSpriteNode(color: spot ? spots : shell, size: CGSize(width: 4,height: 4))
                        tile.position = CGPoint(x: x*4-24,y: (16-y)*4-32); pet.addChild(tile)
                    }
                }
            }
            if !reduceMotion { pet.run(.repeatForever(.sequence([.rotate(toAngle: 0.08,duration: 0.2),.rotate(toAngle: -0.08,duration: 0.2),.rotate(toAngle: 0,duration: 0.2),.wait(forDuration: 1.4)]))) }
            return
        }
        pet.position.y = 6
        guard let species else { pet.texture = nil; return }
        pet.use(species.spriteID,mode: mode)
        pet.play(animation,animated: !reduceMotion && life != .frozen)
        event(animation,previousID: previousID,mode: mode,reduced: reduceMotion)
        if animation == "idle" && life == .alive && !reduceMotion { roaming = true }
        if mode == .advanced && !reduceMotion {
            for i in 0..<7 {
                let n = SKSpriteNode(color: UIColor(red: 0.8,green: 0.95,blue: 0.7,alpha: 0.7),size: CGSize(width: 2,height: 2))
                n.position = CGPoint(x: i*40-140,y: -20+(i*17)%90); n.zPosition = 2; addChild(n)
                n.run(.repeatForever(.sequence([.moveBy(x: 0,y: 8,duration: 1.5),.moveBy(x: 0,y: -8,duration: 1.5)])))
            }
        }
    }
    private func event(_ action: String,previousID: String,mode: DisplayMode,reduced: Bool) {
        let ink = mode == .lcd ? UIColor.darkGray : UIColor.white
        if action == "clean" {
            let water = SKSpriteNode(color: mode == .lcd ? ink.withAlphaComponent(0.4) : UIColor.cyan.withAlphaComponent(0.6),size: CGSize(width: 320,height: 14))
            water.position.y = 80; water.zPosition = 5; addChild(water)
            if !reduced { water.run(.sequence([.moveTo(y: -96,duration: 0.7),.removeFromParent()])) }
        }
        if action == "medicine" || action == "injured" || action == "sleep" {
            let id = action == "sleep" ? "zzz" : "MEDICAL"
            let symbol = PixelSymbols.node(id,color: action == "sleep" ? ink : mode == .lcd ? ink : .systemRed,scale: 3)
            symbol.position = CGPoint(x: 95,y: 54); symbol.zPosition = 5; addChild(symbol)
            if !reduced { symbol.run(.repeatForever(.sequence([.moveBy(x: 0,y: 5,duration: 0.5),.moveBy(x: 0,y: -5,duration: 0.5)]))) }
        }
        if action == "death" || action == "defeat" {
            let grave = PixelSymbols.node("grave",color: ink,scale: 4); grave.position = CGPoint(x: 90,y: -48); grave.zPosition = 5; addChild(grave)
        }
        if action == "evolution",!previousID.isEmpty,previousID != pet.speciesID {
            let old = PixelActor(size: 192); old.use(previousID,mode: mode); old.play("idle",animated: false)
            old.position = pet.position; old.zPosition = 6; addChild(old)
            if !reduced {
                pet.alpha = 0
                old.run(.sequence([.wait(forDuration: 0.4),.fadeOut(withDuration: 0.5),.removeFromParent()]))
                pet.run(.sequence([.wait(forDuration: 0.8),.fadeIn(withDuration: 0.4)]))
            } else { old.removeFromParent() }
        }
    }
    override func update(_ currentTime: TimeInterval) {
        let delta = previousFrame.map { min(0.25,max(0,currentTime-$0)) } ?? 0
        previousFrame = currentTime
        if roaming {
            ambientElapsed += delta
            let pose = AmbientPetTimeline.sample(seconds: ambientElapsed,originX: ambientOrigin)
            pet.position = CGPoint(x: pose.x,y: 6+pose.yOffset)
            pet.face(right: pose.facesRight)
            if pet.pose != pose.action { pet.play(pose.action) }
        }
        pet.tick(delta)
    }
    #if DEBUG
    var diagnostics: String {
        "x=\(Int(pet.position.x));y=\(Int(pet.position.y));pose=\(pet.pose);frame=\(pet.frameIndex);right=\(pet.facingRight);size=\(Int(pet.size.width))"
    }
    #endif

}

struct PetScreen: View {
    @ObservedObject var model: WorldViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = PetScene(size: CGSize(width: 320,height: 240))
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            SpriteView(scene: configured(at: context.date), isPaused: false, preferredFramesPerSecond: 15,
                       options: [.ignoresSiblingOrder])
                .aspectRatio(4/3,contentMode: .fit)
                .accessibilityIdentifier("homePetScreen")
                .accessibilityLabel(model.state?.pet.isEgg == true ? "孵化中的数码蛋" : "像素伙伴 \(model.species?.name ?? "")")
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                Text(scene.diagnostics).font(.system(size: 1)).frame(height: 1)
                    .accessibilityIdentifier("homeMotionProbe")
            }
            #endif
        }
    }
    private func configured(at date: Date) -> PetScene {
        guard let state = model.state else { return scene }
        let date = SandboxEngine.date(for: state,wallTime: date)
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: state.homeTimeZone) ?? .current
        let hour = c.component(.hour, from: date)
        scene.configure(species: model.species, egg: state.pet.isEgg,
                        eggPattern: (try? model.database?.egg(state.pet.eggID).pattern) ?? "spots", life: state.pet.life,
                        animation: model.animationName, mode: state.settings.display,
                        waste: state.pet.stats.waste, dark: state.pet.lightsOff,
                        night: hour < 7 || hour >= 19, reduceMotion: reduceMotion,
                        background: state.dmc?.selectedBackground ?? "grasslands")
        return scene
    }
}
