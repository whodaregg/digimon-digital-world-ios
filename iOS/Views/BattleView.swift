import SwiftUI
import SpriteKit
import DigitalWorldCore

struct BattleView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    @State private var revealed = 0
    @State private var playback: Task<Void, Never>?
    var body: some View {
        if model.isOriginal {
            if let result = model.lastQuest {
                QuestPlaybackView(model: model,result: result)
            } else {
                AdventureView(model: model)
            }
        } else { legacy }
    }
    @ViewBuilder private var legacy: some View {
        if let database = model.database {
            Panel(title: "PVE / 原创离线规则") {
                Text(l("每次对战消耗 15 能量与体力。属性、速度、训练、健康和 DP 参与计算；败北可能受伤。结果会立即保存，再播放战斗记录。"))
                    .font(.footnote).foregroundStyle(Palette.muted)
                if let record = model.lastBattle {
                    HStack {
                        SpriteThumbnail(id: model.state?.pet.speciesID ?? "agumon",size: 80)
                        Spacer(); Text(l("VS")).font(.system(.title,design: .monospaced,weight: .black)).foregroundStyle(Palette.amber); Spacer()
                        SpriteThumbnail(id: record.opponent,size: 80)
                    }
                    ForEach(Array(record.log.prefix(revealed).enumerated()),id: \.offset) { _, line in
                        Text(l(line)).font(.system(.caption,design: .monospaced)).frame(maxWidth: .infinity,alignment: .leading)
                    }
                    if revealed >= record.log.count {
                        Text(l(record.won ? "VICTORY" : "DEFEAT")).font(.system(.largeTitle,design: .monospaced,weight: .black)).foregroundStyle(record.won ? Palette.mint : Palette.amber)
                        Readout(name: "回合",value: "\(record.turns)")
                        Readout(name: "剩余 HP",value: "\(record.hpRemaining)")
                        GameButton(title: "选择下一位对手") { playback?.cancel(); model.lastBattle = nil }
                    } else { Button(l("显示完整记录")) { playback?.cancel(); revealed = record.log.count } }
                } else {
                    ForEach(database.species.filter { $0.stage.order >= Stage.rookie.order }) { species in
                        HStack {
                            SpriteThumbnail(id: species.id,size: 48)
                            VStack(alignment: .leading,spacing: 4) {
                                Text(l(species.name)).font(.headline)
                                Text(l("\(species.attribute.rawValue) · HP \(species.stats.hp)")).font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button(l("对战")) { model.fight(species.id) }.buttonStyle(.bordered)
                                .accessibilityIdentifier("battle-\(species.id)")
                        }
                    }
                }
            }
            if let game = model.state, !game.battles.isEmpty {
                Panel(title: "RECORD / 最近战绩") {
                    ForEach(game.battles.suffix(5).reversed()) { record in
                        Readout(name: record.opponent,value: record.won ? "胜利" : "败北")
                    }
                }
            }
        }
        EmptyView()
            .onChange(of: model.lastBattle?.id) { _, _ in startPlayback() }
            .onAppear { startPlayback() }
            .onDisappear { playback?.cancel() }
    }
    private func startPlayback() {
        playback?.cancel(); revealed = 0
        guard let record = model.lastBattle else { return }
        playback = Task { @MainActor in
            for index in record.log.indices {
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled else { return }
                revealed = index+1
            }
        }
    }
}


struct QuestPlaybackView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    let result: DMCQuestResult
    @StateObject private var replay = QuestPlaybackController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var record: BattleRecord { result.records[replay.battle] }
    var body: some View {
        Panel(title: "QUEST / \(result.area.name)") {
            Text(l("第 \(replay.battle+1) / \(result.area.opponents.count) 战")).font(.headline)
                .accessibilityIdentifier("questBattleNumber")
            Text(l((try? model.database?.species(record.opponent))?.nameSC ?? record.opponent))
                .font(.headline).frame(maxWidth: .infinity)
            TimelineView(.periodic(from: .now,by: 0.1)) { _ in
                SpriteView(scene: replay.scene,preferredFramesPerSecond: 30,options: [.ignoresSiblingOrder])
                    .aspectRatio(4/3,contentMode: .fit)
                    .accessibilityLabel(l("Quest战斗演出"))
                    .accessibilityIdentifier("questArena")
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                    Text(l(replay.scene.diagnostics)).font(.system(size: 1)).frame(height: 1)
                        .accessibilityIdentifier("questAnimationProbe")
                }
                #endif
            }
            Text(l(replay.phase)).font(.title2.bold()).accessibilityIdentifier("questPhase")
            HStack {
                hitMarks(replay.playerHits,title: "伙伴命中",color: Palette.mint)
                Spacer()
                hitMarks(replay.enemyHits,title: "敌人命中",color: Palette.amber)
            }
            if let error = replay.error { Text(l(error)).foregroundStyle(Palette.amber) }
            if replay.finished {
                Text(l(result.cleared ? "本区通关，进度已保存" : "本次挑战结束；再挑战将从本区首战开始"))
                    .font(.subheadline).accessibilityIdentifier("questResult")
                if result.backgroundUnlocked != nil { Text(l("新背景已解锁，可在设置选择")).foregroundStyle(Palette.amber) }
                GameButton(title: "返回区域选择") { model.lastQuest = nil }
            } else if !replay.betweenBattles {
                Button(l("跳过本战演出")) { replay.skip() }
            } else { Text(l("下一位敌人即将登场…")).font(.caption).foregroundStyle(Palette.muted) }
            Text(l("整区结果已保存；关闭页面或跳过演出不会重抽战果。"))
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .onAppear { replay.start(result,database: model.database,mode: model.display,reduceMotion: reduceMotion) }
        .onDisappear { replay.stop() }
    }
    private func hitMarks(_ count: Int,title: String,color: Color) -> some View {
        HStack(spacing: 4) {
            Text(l(title)).font(.caption)
            ForEach(0..<3,id: \.self) { i in Image(systemName: i < count ? "circle.fill" : "circle").foregroundStyle(color) }
        }.accessibilityElement(children: .ignore).accessibilityLabel(l(title)).accessibilityValue(l("\(count) / 3"))
    }
}
