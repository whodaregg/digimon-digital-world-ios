import SwiftUI
import DigitalWorldCore

struct BattleView: View {
    @ObservedObject var model: WorldViewModel
    @State private var revealed = 0
    @State private var playback: Task<Void, Never>?
    var body: some View {
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
