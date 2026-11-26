import SpriteKit
import SwiftUI
import DigitalWorldCore

/// A single LCD scene keeps food and the original character in the same coordinate system.
final class FeedingScene: SKScene {
    private let actor = PixelActor(size: 128)
    private let food = SKCropNode()
    private let mask = SKSpriteNode(color: .white,size: CGSize(width: 36,height: 36))
    private var signature = ""
    private var elapsed: Double = 0
    private var previous: TimeInterval?
    private var refusing = false
    private var reduced = false
    private var remaining: Double = 1
    private var speed = 1.0
    override init(size: CGSize) {
        super.init(size: size); anchorPoint = CGPoint(x: 0.5,y: 0.5); scaleMode = .aspectFit
        actor.position = CGPoint(x: 48,y: 10); addChild(actor)
        food.position = CGPoint(x: -85,y: 15); food.maskNode = mask; addChild(food)
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    func configure(speciesID: String,foodID: String,action: String,mode: DisplayMode,reduceMotion: Bool,duration: Double) {
        let key = "\(speciesID)|\(foodID)|\(action)|\(mode)|\(reduceMotion)"
        guard key != signature else { return }; signature = key
        elapsed = 0; previous = nil; refusing = action == "refuse"; reduced = reduceMotion; remaining = 1
        speed = 2.4/max(0.1,duration)
        backgroundColor = mode == .lcd ? UIColor(red: 0.66,green: 0.73,blue: 0.52,alpha: 1) : UIColor(red: 0.08,green: 0.19,blue: 0.27,alpha: 1)
        actor.use(speciesID,mode: mode); actor.face(right: false); actor.play(action,animated: !reduceMotion)
        food.removeAllChildren()
        let color: UIColor = mode == .lcd ? UIColor(red: 0.19,green: 0.27,blue: 0.19,alpha: 1) : foodID == "meat" ? UIColor(red: 0.76,green: 0.33,blue: 0.20,alpha: 1) : .white
        food.addChild(PixelSymbols.node(foodID,color: color,scale: 4))
        mask.size.width = 36; mask.position.x = 0
    }
    override func update(_ currentTime: TimeInterval) {
        let delta = min(0.1,max(0,currentTime-(previous ?? currentTime))); previous = currentTime
        elapsed += delta*speed; actor.tick(delta*speed)
        if refusing {
            actor.position.x = 48 + (reduced ? 0 : sin(elapsed*13)*4)
        } else {
            remaining = reduced ? 1 : max(0,1-floor(elapsed/0.55)/3)
            mask.size.width = CGFloat(remaining)*36
            mask.position.x = -18+mask.size.width/2
        }
    }
    var diagnostics: String {
        let safe = CGRect(x: -160,y: -65,width: 320,height: 180)
        let foodBounds = CGRect(x: food.position.x-18,y: food.position.y-18,width: 36,height: 36)
        return "pose=\(actor.pose);frame=\(actor.frameIndex);petWithin=\(safe.contains(actor.frame));foodWithin=\(safe.contains(foodBounds));remaining=\(remaining)"
    }
}

struct FeedingScreen: View {
    @ObservedObject var model: WorldViewModel
    @Environment(\.accessibilityReduceMotion) private var reduced
    @State private var scene = FeedingScene(size: CGSize(width: 320,height: 240))
    var body: some View {
        TimelineView(.periodic(from: .now,by: 0.1)) { _ in
            SpriteView(scene: configured(),preferredFramesPerSecond: 30)
                .aspectRatio(4/3,contentMode: .fit).allowsHitTesting(false)
                .accessibilityIdentifier("feedingScene")
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                Text(scene.diagnostics).font(.system(size: 1)).frame(height: 1).accessibilityIdentifier("feedingLayoutProbe")
            }
            #endif
        }
    }
    private func configured() -> FeedingScene {
        scene.configure(speciesID: model.species?.spriteID ?? "agumon",foodID: model.feedingFoodID,action: model.animation,mode: model.display,reduceMotion: reduced,duration: model.feedingDuration)
        return scene
    }
}
