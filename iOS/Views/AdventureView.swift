import SwiftUI
import DigitalWorldCore

struct AdventureView: View {
    @ObservedObject var model: WorldViewModel
    var body: some View {
        if let game = model.state, let map = model.database?.maps.first(where: { $0.id == game.adventure.mapID }) {
            Panel(title: "WORLD / \(map.name)") {
                HStack {
                    Text("收集 3 枚数据碎片").font(.headline)
                    Spacer()
                    Text("\(game.adventure.collected.count) / \(map.questTarget)").font(.system(.headline,design: .monospaced)).foregroundStyle(Palette.amber)
                }
                Text(game.adventure.questComplete ? "任务已完成 · 进化芯片已加入背包" : "沿着小径探索，打开三个宝箱。草地每移动 7 步有机会发现野生伙伴。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Canvas { context,size in
                    let tile = size.width / CGFloat(map.rows[0].count)
                    func rect(_ x: CGFloat,_ y: CGFloat,_ w: CGFloat,_ h: CGFloat,_ color: Color) {
                        context.fill(Path(CGRect(x: x,y: y,width: w,height: h)),with: .color(color))
                    }
                    for y in map.rows.indices {
                        for x in 0..<map.rows[y].count {
                            let value = map.tile(x: x,y: y), xx = CGFloat(x)*tile, yy = CGFloat(y)*tile
                            rect(xx,yy,tile,tile,Color(red: 0.21,green: 0.34,blue: 0.25))
                            if value == "#" {
                                rect(xx+tile*0.1,yy+tile*0.2,tile*0.8,tile*0.7,Color(red: 0.1,green: 0.21,blue: 0.17))
                                rect(xx+tile*0.25,yy+tile*0.05,tile*0.5,tile*0.9,Color(red: 0.1,green: 0.21,blue: 0.17))
                                rect(xx+tile*0.3,yy+tile*0.18,tile*0.25,tile*0.2,Color(red: 0.17,green: 0.29,blue: 0.2))
                            } else if value == "~" {
                                rect(xx,yy,tile,tile,Color(red: 0.18,green: 0.39,blue: 0.48))
                                rect(xx+tile*0.2,yy+tile*0.3,tile*0.5,tile*0.08,Palette.mint.opacity(0.3))
                            } else if value == "C" {
                                let collected = game.adventure.collected.contains("\(map.id):\(x):\(y)")
                                rect(xx+tile*0.15,yy+tile*0.25,tile*0.7,tile*0.55,collected ? Palette.muted : Palette.amber)
                                rect(xx+tile*0.1,yy+tile*0.5,tile*0.8,tile*0.1,Palette.background)
                                rect(xx+tile*0.45,yy+tile*0.45,tile*0.15,tile*0.25,Palette.background)
                            } else if (x+y)%3 == 0 {
                                rect(xx+tile*0.3,yy+tile*0.7,tile*0.1,tile*0.16,Palette.mint.opacity(0.3))
                                rect(xx+tile*0.7,yy+tile*0.4,tile*0.1,tile*0.16,Palette.mint.opacity(0.3))
                            }
                        }
                    }
                    let xx = CGFloat(game.adventure.x)*tile, yy = CGFloat(game.adventure.y)*tile
                    rect(xx+tile*0.25,yy+tile*0.1,tile*0.5,tile*0.5,Palette.mint)
                    rect(xx+tile*0.15,yy+tile*0.55,tile*0.7,tile*0.3,Palette.mint)
                    rect(xx+tile*0.52,yy+tile*0.25,tile*0.13,tile*0.13,Palette.background)
                }.aspectRatio(CGFloat(map.rows[0].count)/CGFloat(map.rows.count),contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel("信号花园，当前位置横坐标 \(game.adventure.x)，纵坐标 \(game.adventure.y)")
                Text(model.message).font(.caption).foregroundStyle(Palette.amber).frame(minHeight: 30)
                HStack {
                    VStack(alignment: .leading,spacing: 8) {
                        SpriteThumbnail(id: game.pet.speciesID,size: 64)
                        Text(model.species?.name ?? "").font(.caption)
                        Text("ENERGY \(game.pet.stats.energy)").font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    VStack(spacing: 5) {
                        direction("arrow.up",dx: 0,dy: -1)
                        HStack(spacing: 5) {
                            direction("arrow.left",dx: -1,dy: 0)
                            Image(systemName: "circle.fill").foregroundStyle(Palette.line).frame(width: 44,height: 44)
                            direction("arrow.right",dx: 1,dy: 0)
                        }
                        direction("arrow.down",dx: 0,dy: 1)
                    }
                }
                if let encounter = model.encounter {
                    HStack {
                        Text("发现 \(encounter)").font(.subheadline)
                        Spacer()
                        Button("挑战") { model.fight(encounter); model.encounter = nil }.buttonStyle(.bordered)
                        Button("离开") { model.encounter = nil }
                    }
                    if let battle = model.lastBattle {
                        Text(battle.won ? "最近战斗胜利" : "最近战斗败北，请检查伤势").font(.caption).foregroundStyle(Palette.amber)
                    }
                }
            }
        }
    }
    private func direction(_ symbol: String,dx: Int,dy: Int) -> some View {
        Button { model.move(dx: dx,dy: dy) } label: {
            Image(systemName: symbol).font(.system(size: 17,weight: .bold)).frame(width: 44,height: 44)
                .background(Palette.line,in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).foregroundStyle(Palette.mint).accessibilityLabel("移动 \(symbol)")
    }
}
