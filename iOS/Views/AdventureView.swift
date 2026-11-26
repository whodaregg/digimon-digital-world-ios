import SwiftUI
import DigitalWorldCore

/// Ver.1 has an ordered quest ladder, never a free directional map.
struct AdventureView: View {
    @ObservedObject var model: WorldViewModel
    var body: some View {
        if model.isOriginal, let game = model.state, let rules = model.database?.dmcV1 {
            Panel(title: "QUEST / 顺序闯关") {
                Text("按区域顺序挑战")
                    .font(.title3.bold()).accessibilityIdentifier("questHeading")
                Text("每区固定连续战斗；先命中3次获胜。全胜解锁下一区，落败后需从本区首战重来。每次整区挑战消耗1 DP、减重6g。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                HStack {
                    SpriteThumbnail(id: game.pet.speciesID,size: 64)
                    Spacer()
                    Readout(name: "DP",value: "\(game.pet.stats.dp)")
                }
                ForEach(rules.areas) { area in
                    let unlocked = area.id == 1 || game.dmc!.clearedAreas.contains(area.id-1)
                    let cleared = game.dmc!.clearedAreas.contains(area.id)
                    VStack(alignment: .leading,spacing: 12) {
                        HStack {
                            Image(systemName: cleared ? "checkmark.circle.fill" : unlocked ? "circle" : "lock.fill")
                                .foregroundStyle(unlocked ? Palette.mint : Palette.muted)
                            Text(area.name).font(.system(.headline,design: .monospaced))
                            Spacer()
                            Text(cleared ? "已通关" : unlocked ? "可挑战" : "未解锁").font(.caption)
                        }
                        HStack(spacing: 0) {
                            ForEach(Array(area.opponents.enumerated()),id: \.offset) { index,enemy in
                                VStack(spacing: 4) {
                                    SpriteThumbnail(id: enemy.speciesID,size: 44)
                                    Text(index == area.opponents.count-1 ? "BOSS" : "\(index+1)")
                                        .font(.system(size: 9,design: .monospaced)).foregroundStyle(Palette.muted)
                                }.frame(maxWidth: .infinity)
                                if index < area.opponents.count-1 { Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(Palette.muted) }
                            }
                        }
                        GameButton(title: unlocked ? "挑战 \(area.name)" : "先完成前一区域") { model.quest(area.id) }
                            .disabled(!unlocked || game.pet.isEgg || game.pet.life != .alive)
                            .accessibilityIdentifier("quest-area-\(area.id)")
                    }.padding(.vertical,10)
                    Divider().overlay(Palette.line)
                }
                Text("手机对战请使用连接页面；联展尚未开放。奥米加兽 Alter-S 现为最终区敌人。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        } else {
            Panel(title: "旧版养成档案") {
                Text("此存档采用早期实验规则。开始 Ver.1 后即可按实体机形式养成和顺序闯关，当前档案会另存备份。")
                    .font(.subheadline)
                GameButton(title: "备份旧档并开始 Ver.1") { model.startOriginalProfile() }
            }
        }
    }
}
