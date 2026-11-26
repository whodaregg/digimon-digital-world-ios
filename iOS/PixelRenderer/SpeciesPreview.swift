import SwiftUI
import SpriteKit
import DigitalWorldCore

final class SpeciesPreviewScene: SKScene {
    private let actor = PixelActor(size: 192)
    private var signature = "", previous: TimeInterval?
    override init(size: CGSize) {
        super.init(size: size); anchorPoint = CGPoint(x: 0.5,y: 0.5); scaleMode = .aspectFit
        backgroundColor = .clear; addChild(actor)
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    func configure(id: String,action: String,mode: DisplayMode,reduced: Bool) {
        let key = "\(id):\(action):\(mode):\(reduced)"; guard key != signature else { return }; signature = key
        actor.use(id,mode: mode); actor.play(action,animated: !reduced)
    }
    override func update(_ currentTime: TimeInterval) {
        let delta = previous.map { min(0.25,max(0,currentTime-$0)) } ?? 0; previous = currentTime; actor.tick(delta)
    }
}
struct SpeciesPreview: View {
    let id: String
    var mode: DisplayMode = .color
    @State private var action = "idle"
    @State private var scene = SpeciesPreviewScene(size: CGSize(width: 240,height: 220))
    @Environment(\.accessibilityReduceMotion) private var reduced
    private let actions = ["idle","walk","happy","sad","hungry","eat","refuse","sleep","wake","sick","injured","training","attack","critical","dodge","hit","victory","defeat","evolution","death"]
    var body: some View {
        VStack {
            SpriteView(scene: configured,options: [.allowsTransparency]).frame(height: 180)
            Picker("动作预览",selection: $action) { ForEach(actions,id: \.self) { Text($0).tag($0) } }.accessibilityIdentifier("animationPreview")
            if PixelAtlas.manifest?.sprites[id]?.animations[action] == nil {
                Text("此动作使用已有原图姿势回退，非新增官方动画帧。")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
    }
    private var configured: SpeciesPreviewScene { scene.configure(id: id,action: action,mode: mode,reduced: reduced); return scene }
}
