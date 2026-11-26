import SwiftUI
import SpriteKit
import DigitalWorldCore

final class TrainingScene: SKScene {
    private let pet = PixelActor(size: 128), defender = PixelActor(size: 128)
    private var signature = "", choicesSeen = 0
    private var previous: TimeInterval?
    override init(size: CGSize) {
        super.init(size: size); anchorPoint = CGPoint(x: 0.5,y: 0.5); scaleMode = .aspectFit
        pet.position = CGPoint(x: -75,y: -10); defender.position = CGPoint(x: 75,y: -10)
        addChild(pet); addChild(defender)
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    func configure(species: Species?,choices: [String],hits: [Bool],mode: DisplayMode,reduceMotion: Bool) {
        guard let species else { return }
        let key = "\(species.id):\(choices):\(hits):\(mode)"
        guard key != signature else { return }; signature = key
        let lcd = mode == .lcd
        backgroundColor = lcd ? .init(red: 0.66,green: 0.73,blue: 0.52,alpha: 1) : .init(red: 0.35,green: 0.69,blue: 0.91,alpha: 1)
        pet.use(species.spriteID,mode: mode); defender.use(species.spriteID,mode: mode)
        pet.face(right: true); defender.face(right: false)
        pet.play("idle",animated: !reduceMotion); defender.play("idle",animated: !reduceMotion)
        if choices.count > choicesSeen,let choice = choices.last,let hit = hits.last {
            pet.play("attack",animated: !reduceMotion)
            let shot = PixelSymbols.node("meat",color: lcd ? .darkGray : .systemRed,scale: 4)
            shot.name = "training-shot"; shot.position = CGPoint(x: -15,y: choice == "A" ? 20 : -24); addChild(shot)
            let finish = SKAction.run { [weak self,weak shot] in
                guard let self else { return }
                self.defender.play(hit ? "hit" : "attack",animated: !reduceMotion)
                shot?.removeFromParent()
                if !hit {
                    let shield = SKSpriteNode(color: lcd ? .darkGray : .systemOrange,size: CGSize(width: 8,height: 25))
                    shield.position = CGPoint(x: 30,y: choice == "A" ? 20 : -24); self.addChild(shield)
                    shield.run(.sequence([.wait(forDuration: 0.3),.removeFromParent()]))
                }
            }
            shot.run(.sequence([reduceMotion ? .wait(forDuration: 0.3) : .moveTo(x: 42,duration: 0.3),finish]))
        }
        choicesSeen = choices.count
    }
    override func update(_ currentTime: TimeInterval) {
        let delta = previous.map { min(0.25,max(0,currentTime-$0)) } ?? 0; previous = currentTime
        pet.tick(delta); defender.tick(delta)
    }
}
struct TrainingPixelScreen: View {
    @ObservedObject var model: WorldViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene = TrainingScene(size: CGSize(width: 320,height: 160))
    var body: some View {
        SpriteView(scene: configured,preferredFramesPerSecond: 30).aspectRatio(2,contentMode: .fit).allowsHitTesting(false)
    }
    private var configured: TrainingScene {
        scene.configure(species: model.species,choices: model.state?.dmc?.trainingChoices ?? [],hits: model.state?.dmc?.trainingHits ?? [],mode: model.display,reduceMotion: reduceMotion)
        return scene
    }
}
