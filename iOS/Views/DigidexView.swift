import SwiftUI
import DigitalWorldCore

struct SpriteThumbnail: View {
    let id: String
    var size: CGFloat = 48
    var silhouette = false
    var body: some View {
        Group {
            if let data = try? SpriteLibrary.imageData(id: id), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().interpolation(.none)
                    .frame(width: size*3,height: size*15)
                    .frame(width: size,height: size,alignment: .topLeading).clipped()
                    .brightness(silhouette ? -1 : 0)
            } else {
                Image(systemName: "questionmark.square.dashed").frame(width: size,height: size)
                    .accessibilityLabel("像素素材缺失")
            }
        }.accessibilityHidden(true)
    }
}

struct DigidexView: View {
    @ObservedObject var model: WorldViewModel
    @State private var query = ""
    @State private var attribute = "all"
    @State private var stage = "all"
    @State private var selected: Species?
    var body: some View {
        if let database = model.database {
            Panel(title: "DIGIDEX / \(model.state?.dex.count ?? 0) OF \(database.species.count)") {
                let raised = model.state?.dex.values.filter { $0 == .raised }.count ?? 0
                Readout(name: "已养成完成度",value: "\(raised * 100 / max(1,database.species.count))%")
                TextField("搜索名称 / ID",text: $query).textFieldStyle(.roundedBorder)
                HStack {
                    Picker("属性",selection: $attribute) {
                        Text("全部属性").tag("all")
                        ForEach(Attribute.allCases,id: \.self) { value in Text(value.rawValue).tag(value.rawValue) }
                    }
                    Picker("阶段",selection: $stage) {
                        Text("全部阶段").tag("all")
                        ForEach(Stage.allCases,id: \.self) { value in Text(value.rawValue).tag(value.rawValue) }
                    }
                }.pickerStyle(.menu)
                let filtered = database.species.filter { species in
                    (query.isEmpty || [species.name,species.nameSC,species.nameTC,species.nameJP,species.id].contains { $0.localizedCaseInsensitiveContains(query) }) &&
                    (attribute == "all" || species.attribute.rawValue == attribute) && (stage == "all" || species.stage.rawValue == stage)
                }
                if filtered.isEmpty { Text("没有匹配角色，请调整筛选条件。").font(.footnote).foregroundStyle(Palette.muted) }
                ForEach(filtered) { species in
                    let discovery = model.state?.dex[species.id]
                    Button { selected = species } label: {
                        HStack(spacing: 14) {
                            SpriteThumbnail(id: species.id,size: 56,silhouette: discovery == nil)
                                .background(Palette.muted.opacity(0.15),in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading,spacing: 4) {
                                Text(discovery == nil ? "???" : species.name).font(.headline)
                                Text(discovery == nil ? "未发现" : discovery == .raised ? "已养成" : "已遭遇")
                                    .font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Text(species.stage.rawValue.uppercased()).font(.system(size: 8,design: .monospaced)).foregroundStyle(Palette.amber)
                            Image(systemName: "chevron.right").font(.caption2)
                        }.padding(.vertical,4)
                    }.buttonStyle(.plain)
                }
            }
            Panel(title: "EVOLUTION / 原创规则分支") {
                Text("双指缩放、上下左右拖动。以下为本游戏养成路线，并非实体机官方条件。")
                    .font(.caption).foregroundStyle(Palette.muted)
                EvolutionTreeView(species: database.species)
            }
            Text("数据库目前包含 8 个角色，不代表全部官方角色；素材为独立原创测试像素研究稿。")
                .font(.caption2).foregroundStyle(Palette.muted)
        }
        EmptyView().sheet(item: $selected) { species in
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        Panel(title: species.name.uppercased()) {
                            SpriteThumbnail(id: species.id,size: 120).frame(maxWidth: .infinity)
                            Text("\(species.nameSC) / \(species.nameTC) / \(species.nameJP)").font(.subheadline)
                            Readout(name: "阶段",value: species.stage.rawValue)
                            Readout(name: "种族",value: species.type)
                            Readout(name: "属性",value: species.attribute.rawValue)
                            Readout(name: "必杀技",value: species.specialMove)
                            Readout(name: "HP / 攻击 / 防御",value: "\(species.stats.hp) / \(species.stats.attack) / \(species.stats.defense)")
                            Readout(name: "首次登场",value: species.firstAppearance ?? "待核验")
                            Text("全部战斗数值、睡眠、寿命及进化条件为原创平衡参数。中文译名待复核。")
                                .font(.caption).foregroundStyle(Palette.amber)
                            Text("官方资料已核验字段：\(species.verifiedFields.isEmpty ? "待核验" : species.verifiedFields.joined(separator: ", "))")
                                .font(.caption).foregroundStyle(Palette.muted)
                            if let source = species.referenceURL, let url = URL(string: source) { Link("官方角色资料",destination: url) }
                        }
                        if !species.evolutions.isEmpty {
                            Panel(title: "BRANCHES / 条件") {
                                ForEach(species.evolutions) { rule in
                                    VStack(alignment: .leading,spacing: 6) {
                                        Text("→ \(rule.target)").font(.headline).foregroundStyle(Palette.mint)
                                        Text("阶段成长 ≥\(rule.stageMinutes) 分钟 · 训练 ≥\(rule.minimumTraining) · 战斗 ≥\(rule.minimumBattles)")
                                        Text("胜率 ≥\(Int(rule.minimumWinRate*100))% · 失误 \(rule.minimumMistakes)…\(rule.maximumMistakes.map(String.init) ?? "不限")")
                                        Text("健康 ≥\(rule.minimumHealth) · 体重 \(rule.minimumWeight)…\(rule.maximumWeight)g · 亲密 ≥\(rule.minimumBond)")
                                        if let item = rule.requiredItem { Text("需要道具：\(item)") }
                                        Text("优先级 \(rule.priority)，健康且无伤病时检查")
                                    }.font(.caption).foregroundStyle(Palette.muted).padding(.vertical,5)
                                }
                            }
                        }
                    }.pageStyle()
                }.background(Palette.background).navigationTitle(species.name).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { selected = nil } } }
            }
        }
    }
}

struct EvolutionTreeView: View {
    let species: [Species]
    @State private var zoom: CGFloat = 1
    @GestureState private var gestureZoom: CGFloat = 1
    private var effectiveZoom: CGFloat { min(2,max(0.5,zoom*gestureZoom)) }
    private func origin(_ s: Species) -> CGPoint {
        let peers = species.filter { $0.stage == s.stage }.sorted { $0.id < $1.id }
        return CGPoint(x: CGFloat(max(0,s.stage.order-1))*165+8,y: CGFloat(peers.firstIndex(where: { $0.id == s.id }) ?? 0)*100+8)
    }
    var body: some View {
        ScrollView([.horizontal,.vertical]) {
            ZStack(alignment: .topLeading) {
                Canvas { context,_ in
                    for s in species {
                        let source = origin(s)
                        for rule in s.evolutions {
                            if let target = species.first(where: { $0.id == rule.target }) {
                                let end = origin(target)
                                var path = Path()
                                path.move(to: CGPoint(x: source.x+135,y: source.y+36))
                                path.addLine(to: CGPoint(x: end.x,y: end.y+36))
                                context.stroke(path,with: .color(Palette.mint.opacity(0.4)),lineWidth: 1)
                            }
                        }
                    }
                }
                ForEach(species) { s in
                    VStack(alignment: .leading,spacing: 5) {
                        Text(s.name).font(.system(.caption,design: .monospaced,weight: .bold)).foregroundStyle(Palette.mint)
                        Text(s.stage.rawValue.uppercased()).font(.system(size: 9,design: .monospaced)).foregroundStyle(Palette.muted)
                    }.frame(width: 115,height: 50,alignment: .leading).padding(10)
                        .background(Palette.background,in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.line,lineWidth: 1))
                        .offset(x: origin(s).x,y: origin(s).y)
                }
            }.frame(width: 835,height: 320,alignment: .topLeading)
                .scaleEffect(effectiveZoom,anchor: .topLeading)
                .frame(width: 835*effectiveZoom,height: 320*effectiveZoom,alignment: .topLeading)
        }.frame(height: 290)
            .simultaneousGesture(MagnifyGesture().updating($gestureZoom) { value,state,_ in state = value.magnification }
                .onEnded { value in zoom = min(2,max(0.5,zoom*value.magnification)) })
            .accessibilityLabel("可缩放的原创进化路线图")
    }
}
