import SwiftUI
import DigitalWorldCore

struct BattleView: View {
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
                Text("每次对战消耗 15 能量与体力。属性、速度、训练、健康和 DP 参与计算；败北可能受伤。结果会立即保存，再播放战斗记录。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                if let record = model.lastBattle {
                    HStack {
                        SpriteThumbnail(id: model.state?.pet.speciesID ?? "agumon",size: 80)
                        Spacer(); Text("VS").font(.system(.title,design: .monospaced,weight: .black)).foregroundStyle(Palette.amber); Spacer()
                        SpriteThumbnail(id: record.opponent,size: 80)
                    }
                    ForEach(Array(record.log.prefix(revealed).enumerated()),id: \.offset) { _, line in
                        Text(line).font(.system(.caption,design: .monospaced)).frame(maxWidth: .infinity,alignment: .leading)
                    }
                    if revealed >= record.log.count {
                        Text(record.won ? "VICTORY" : "DEFEAT").font(.system(.largeTitle,design: .monospaced,weight: .black)).foregroundStyle(record.won ? Palette.mint : Palette.amber)
                        Readout(name: "回合",value: "\(record.turns)")
                        Readout(name: "剩余 HP",value: "\(record.hpRemaining)")
                        GameButton(title: "选择下一位对手") { playback?.cancel(); model.lastBattle = nil }
                    } else { Button("显示完整记录") { playback?.cancel(); revealed = record.log.count } }
                } else {
                    ForEach(database.species.filter { $0.stage.order >= Stage.rookie.order }) { species in
                        HStack {
                            SpriteThumbnail(id: species.id,size: 48)
                            VStack(alignment: .leading,spacing: 4) {
                                Text(species.name).font(.headline)
                                Text("\(species.attribute.rawValue) · HP \(species.stats.hp)").font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button("对战") { model.fight(species.id) }.buttonStyle(.bordered)
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
    @ObservedObject var model: WorldViewModel
    let result: DMCQuestResult
    @State private var battle = 0
    @State private var revealed = 0
    @State private var playback: Task<Void,Never>?
    private var record: BattleRecord { result.records[battle] }
    var body: some View {
        Panel(title: "QUEST / \(result.area.name)") {
            Text("第 \(battle+1) / \(result.area.opponents.count) 战").font(.headline)
            HStack {
                SpriteThumbnail(id: model.state?.pet.speciesID ?? "agumon",size: 100)
                Spacer(); Text("VS").font(.title.bold()).foregroundStyle(Palette.amber); Spacer()
                SpriteThumbnail(id: record.opponent,size: 100).scaleEffect(x: -1,y: 1)
            }
            Text((try? model.database?.species(record.opponent))?.nameSC ?? record.opponent)
                .font(.headline).frame(maxWidth: .infinity)
            HStack {
                hitMarks(record.log.prefix(revealed).filter { $0.hasPrefix("攻击命中") }.count,color: Palette.mint)
                Spacer()
                hitMarks(record.log.prefix(revealed).filter { $0.hasPrefix("受到攻击") }.count,color: Palette.amber)
            }
            ForEach(Array(record.log.prefix(revealed).enumerated()),id: \.offset) { _,line in
                Text(line).font(.system(.subheadline,design: .monospaced))
            }
            if revealed < record.log.count {
                Button("显示本战结果") { playback?.cancel(); revealed = record.log.count }
            } else {
                Text(record.won ? "胜利" : "败北").font(.largeTitle.bold()).foregroundStyle(record.won ? Palette.mint : Palette.amber)
                if battle+1 < result.records.count {
                    GameButton(title: "继续下一战") { battle += 1; startPlayback() }
                } else {
                    Text(result.cleared ? "本区通关，进度已保存" : "本次挑战结束；再挑战将从本区首战开始")
                        .font(.subheadline).accessibilityIdentifier("questResult")
                    if result.backgroundUnlocked != nil { Text("新背景已解锁，可在设置选择").foregroundStyle(Palette.amber) }
                    GameButton(title: "返回区域选择") { model.lastQuest = nil }
                }
            }
            Text("整区结果已保存；关闭页面或跳过演出不会重抽战果。")
                .font(.caption).foregroundStyle(Palette.muted)
        }.onAppear { startPlayback() }.onDisappear { playback?.cancel() }
    }
    private func hitMarks(_ count: Int,color: Color) -> some View {
        HStack { ForEach(0..<3,id: \.self) { i in Image(systemName: i < count ? "circle.fill" : "circle").foregroundStyle(color) } }
    }
    private func startPlayback() {
        playback?.cancel(); revealed = 0
        let lines = record.log.count
        playback = Task { @MainActor in
            for i in 1...lines {
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                revealed = i
            }
        }
    }
}
