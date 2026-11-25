import SpriteKit
import DigitalWorldCore

/// Ver.1 Quest presentation: alternating cutaways, evasion, hit mark, then result.
/// The recorded outcome is immutable; this scene never runs the battle engine.
final class QuestBattleScene: SKScene {
    private let player = PixelActor(size: 160)
    private let enemy = PixelActor(size: 160)
    private let effects = SKNode()
    private let scenery = SKNode()
    private var mode: DisplayMode = .color
    private var reduced = false
    private var playerEffect = "fire", enemyEffect = "electric"
    private(set) var phase = "准备"
    var onPhase: ((String) -> Void)?
    var onHit: ((BattleReplayRound) -> Void)?
    var onFinished: (() -> Void)?
    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .aspectFit; anchorPoint = CGPoint(x: 0.5,y: 0.5)
        addChild(scenery); addChild(player); addChild(enemy); addChild(effects)
        player.zPosition = 2; enemy.zPosition = 2; effects.zPosition = 4
    }
    required init?(coder: NSCoder) { fatalError("Storyboard initialization is not supported") }
    func play(player species: Species,opponent: Species,record: BattleRecord,rounds: [BattleReplayRound],
              mode: DisplayMode,reduceMotion: Bool,boss: Bool) {
        stop(); self.mode = mode; reduced = reduceMotion
        player.use(species.spriteID,mode: mode); enemy.use(opponent.spriteID,mode: mode)
        playerEffect = species.effect; enemyEffect = opponent.effect
        backdrop(); show(.opponent,pose: "idle")
        setPhase(boss ? "BOSS登场" : "敌人登场")
        var actions: [SKAction] = [.wait(forDuration: 0.9),.run { [weak self] in self?.card("BATTLE") },.wait(forDuration: 0.6)]
        for round in rounds {
            actions += attack(.player,lands: round.winner == .player,round: round)
            // A third hit ends immediately: there is no extra enemy shot after victory.
            if round.playerHits < 3 { actions += attack(.opponent,lands: round.winner == .opponent,round: round) }
        }
        actions += [.run { [weak self] in self?.result(won: record.won) },.wait(forDuration: 1.6),
                    .run { [weak self] in self?.onFinished?() }]
        run(.sequence(actions),withKey: "quest")
    }
    func stop() {
        removeAllActions(); player.removeAllActions(); enemy.removeAllActions()
        effects.removeAllChildren(); player.alpha = 1; enemy.alpha = 1
    }
    func skip(won: Bool) {
        stop(); result(won: won)
        run(.sequence([.wait(forDuration: 0.5),.run { [weak self] in self?.onFinished?() }]),withKey: "quest")
    }
    private func setPhase(_ text: String) { phase = text; onPhase?(text) }
    private func actor(_ side: BattleSide) -> PixelActor { side == .player ? player : enemy }
    private func opposite(_ side: BattleSide) -> BattleSide { side == .player ? .opponent : .player }
    private func show(_ side: BattleSide,pose: String) {
        effects.removeAllChildren()
        player.isHidden = side != .player; enemy.isHidden = side != .opponent
        let a = actor(side)
        a.removeAllActions(); a.alpha = 1
        a.position = CGPoint(x: side == .player ? 55 : -55,y: -6)
        a.face(right: side == .opponent); a.play(pose,animated: !reduced)
    }
    private func attack(_ side: BattleSide,lands: Bool,round: BattleReplayRound) -> [SKAction] {
        [
            .run { [weak self] in
                guard let self else { return }
                self.show(side,pose: "attack")
                self.setPhase(side == .player ? "伙伴攻击" : "敌人攻击")
                let shot = self.projectile(side == .player ? self.playerEffect : self.enemyEffect)
                shot.name = "projectile"; shot.position = CGPoint(x: side == .player ? -18 : 18,y: 6)
                shot.xScale = side == .player ? -1 : 1; self.effects.addChild(shot)
                if !self.reduced { shot.run(.moveTo(x: side == .player ? -185 : 185,duration: 0.65)) }
            },
            .wait(forDuration: 0.7),
            .run { [weak self] in
                guard let self else { return }
                if lands {
                    self.hitMark(); self.onHit?(round)
                    self.setPhase(side == .player ? "攻击命中" : "受到攻击")
                } else {
                    let target = self.opposite(side)
                    self.show(target,pose: "hit")
                    self.setPhase(target == .player ? "伙伴回避" : "敌人回避")
                    if !self.reduced {
                        let a = self.actor(target), x = a.position.x
                        a.run(.sequence([.moveBy(x: target == .player ? 24 : -24,y: 0,duration: 0.12),
                                         .wait(forDuration: 0.18),.moveTo(x: x,duration: 0.12)]),withKey: "dodge")
                    }
                }
            },.wait(forDuration: 0.6)
        ]
    }
    private var ink: UIColor { mode == .lcd ? UIColor(red: 0.19,green: 0.27,blue: 0.19,alpha: 1) : .black }
    @discardableResult private func block(_ parent: SKNode,_ x: CGFloat,_ y: CGFloat,_ w: CGFloat,_ h: CGFloat,_ color: UIColor) -> SKSpriteNode {
        let n = SKSpriteNode(color: color,size: CGSize(width: w,height: h)); n.position = CGPoint(x: CGFloat(x),y: CGFloat(y)); parent.addChild(n); return n
    }
    private func pixels(_ rows: [String],color: UIColor,scale: CGFloat = 4) -> SKNode {
        let node = SKNode()
        for (y,row) in rows.enumerated() {
            for (x,c) in row.enumerated() where c == "#" {
                block(node,(CGFloat(x)-CGFloat(row.count-1)/2)*scale,(CGFloat(rows.count-1)/2-CGFloat(y))*scale,scale,scale,color)
            }
        }
        return node
    }
    private func projectile(_ effect: String) -> SKNode {
        // Reconstructed pixel effects; the archived character sheets have no projectile tiles.
        let fire = ["..##.....",".#####...","########.",".########","########.",".#####...","..##....."]
        let bolt = ["....##...","...##....","..#####..","....##...","...##....","..##.....",".##......"]
        let ball = ["..####...",".######..","########.","########.","########.",".######..","..####..."]
        let rows = ["electric","ice","wind","sword","claw"].contains(effect) ? bolt : ["bubble","bomb","sludge","heart"].contains(effect) ? ball : fire
        let color: UIColor = mode == .lcd ? ink : effect == "electric" ? .yellow : effect == "bubble" || effect == "ice" ? .cyan : effect == "sludge" ? .purple : .systemOrange
        let n = pixels(rows,color: color)
        if !reduced { n.run(.repeatForever(.sequence([.scaleY(to: 0.85,duration: 0.1),.scaleY(to: 1,duration: 0.1)]))) }
        return n
    }
    private func skull(color: UIColor,scale: CGFloat = 5) -> SKNode {
        pixels(["..#####..",".#######.","#########","##..#..##","##..#..##",".#######.","..#.#.#..","..#####.."],color: color,scale: scale)
    }
    private func hitMark() {
        effects.removeAllChildren(); player.isHidden = true; enemy.isHidden = true
        let mark = SKNode(); mark.name = "hitMark"; effects.addChild(mark)
        block(mark,0,0,320,200,mode == .lcd ? UIColor(red: 0.66,green: 0.73,blue: 0.52,alpha: 1) : .systemYellow)
        for i in 0..<10 {
            let x = CGFloat(i*36-160)
            block(mark,x,94,14,12,ink); block(mark,x+12,-94,14,12,ink)
        }
        for y in [-60,0,60] { block(mark,-154,CGFloat(y),12,24,ink); block(mark,154,CGFloat(y),12,24,ink) }
        mark.addChild(skull(color: mode == .lcd ? ink : UIColor(red: 0.19,green: 0.16,blue: 0.39,alpha: 1),scale: 7))
        // The manual's hit-mark cutaway blinks. Respect Reduce Motion with a static mark.
        if !reduced { mark.run(.sequence([.wait(forDuration: 0.15),.fadeAlpha(to: 0.3,duration: 0.06),.fadeAlpha(to: 1,duration: 0.06)])) }
    }
    private func result(won: Bool) {
        show(.player,pose: won ? "victory" : "defeat"); player.position.x = 0
        setPhase(won ? "胜利" : "败北")
        for x in [-110,110] {
            if won {
                let sparkle = pixels(["..#..","#.#.#",".###.","#.#.#","..#.."],color: mode == .lcd ? ink : .systemOrange)
                sparkle.position = CGPoint(x: CGFloat(x),y: 20); effects.addChild(sparkle)
                if !reduced { sparkle.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2,duration: 0.25),.fadeAlpha(to: 1,duration: 0.25)]))) }
            } else {
                for y in [-30,50] { let n = skull(color: mode == .lcd ? ink : .systemIndigo,scale: 3); n.position = CGPoint(x: CGFloat(x),y: CGFloat(y)); effects.addChild(n) }
            }
        }
    }
    private func card(_ text: String) {
        player.isHidden = true; enemy.isHidden = true; effects.removeAllChildren()
        block(effects,0,0,320,200,ink)
        let label = SKLabelNode(fontNamed: "Menlo-Bold"); label.text = text
        label.fontSize = 46; label.fontColor = mode == .lcd ? .init(red: 0.66,green: 0.73,blue: 0.52,alpha: 1) : .systemGreen
        label.verticalAlignmentMode = .center; effects.addChild(label); setPhase("战斗开始")
    }
    private func backdrop() {
        scenery.removeAllChildren()
        let lcd = mode == .lcd
        backgroundColor = lcd ? UIColor(red: 0.66,green: 0.73,blue: 0.52,alpha: 1) : UIColor(red: 0.35,green: 0.69,blue: 0.91,alpha: 1)
        for i in 0..<6 {
            let x = CGFloat(i*65-160), c = lcd ? ink.withAlphaComponent(0.15) : UIColor(red: 0.37,green: 0.51,blue: 0.69,alpha: 1)
            block(scenery,x,-30,70,40,c); block(scenery,x,-4,40,14,c); block(scenery,x,6,18,8,c)
        }
        block(scenery,0,-84,320,34,lcd ? ink.withAlphaComponent(0.18) : .init(red: 0.42,green: 0.66,blue: 0.25,alpha: 1))
        block(scenery,0,-67,320,3,lcd ? ink.withAlphaComponent(0.45) : .init(red: 0.68,green: 0.84,blue: 0.39,alpha: 1))
    }
    #if DEBUG
    var diagnostics: String {
        let a = player.isHidden ? enemy : player
        return "phase=\(phase);actor=\(a.speciesID);x=\(Int(a.position.x));frame=\(a.frameIndex);pose=\(a.pose);right=\(a.facingRight);shot=\(effects.childNode(withName: "projectile") != nil);mark=\(effects.childNode(withName: "hitMark") != nil)"
    }
    #endif
}
