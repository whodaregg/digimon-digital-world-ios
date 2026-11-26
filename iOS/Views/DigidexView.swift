import SwiftUI
import DigitalWorldCore

struct SpriteThumbnail: View {
    private static let manifest = try? SpriteLibrary.manifest()
    let id: String
    var size: CGFloat = 48
    var silhouette = false
    var body: some View {
        Group {
            if let definition = Self.manifest?.sprites[id],
               let data = try? SpriteLibrary.imageData(id: id), let image = UIImage(data: data) {
                Image(uiImage: image).resizable().interpolation(.none)
                    .frame(width: size*CGFloat(definition.columns),height: size*CGFloat(definition.rows))
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
    @State private var deviceFilter = "all"
    @State private var collectionFilter = "all"
    var body: some View {
        Group {
        if let database = model.database {
            Panel(title: "DIGIDEX / \(model.state?.dex.count ?? 0) OF \(database.species.count)") {
                let raised = model.isSandbox ? model.state?.dex.values.filter { $0 == .raised }.count ?? 0 : model.collectionEntries.filter { $0.discovery == .raised }.count
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
                HStack {
                    Picker(model.text(.device),selection: $deviceFilter) {
                        Text(model.text(.all)).tag("all")
                        ForEach(database.devices.filter { $0.enabled }) { Text($0.name).tag($0.id) }
                    }
                    Picker(model.text(.collection),selection: $collectionFilter) {
                        Text(model.text(.all)).tag("all"); Text("已发现").tag("discovered"); Text("已养成").tag("raised")
                    }
                }.pickerStyle(.menu)
                if model.isSandbox { Text("SANDBOX图鉴 · 不计入正式收藏").font(.caption).foregroundStyle(Palette.amber) }
                let filtered = database.species.filter { species in
                    (query.isEmpty || [species.name,species.nameSC,species.nameTC,species.nameJP,species.id].contains { $0.localizedCaseInsensitiveContains(query) }) &&
                    (attribute == "all" || species.attribute.rawValue == attribute) && (stage == "all" || species.stage.rawValue == stage) &&
                    (deviceFilter == "all" || species.devices.contains(deviceFilter)) &&
                    (collectionFilter == "all" || discovery(species.id) != nil && (collectionFilter != "raised" || discovery(species.id) == .raised))
                }
                if filtered.isEmpty { Text("没有匹配角色，请调整筛选条件。").font(.footnote).foregroundStyle(Palette.muted) }
                ForEach(filtered) { species in
                    let discovery = discovery(species.id)
                    Button { selected = species } label: {
                        HStack(spacing: 14) {
                            SpriteThumbnail(id: species.id,size: 56,silhouette: discovery == nil)
                                .background(Palette.muted.opacity(0.15),in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading,spacing: 4) {
                                Text(discovery == nil ? "???" : species.localizedName(model.language)).font(.headline)
                                if discovery != nil && model.language != .english { Text(species.name).font(.caption2) }
                                Text(discovery == nil ? "未发现" : discovery == .raised ? "已养成" : "已遭遇")
                                    .font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Text(species.stage.rawValue.uppercased()).font(.system(size: 8,design: .monospaced)).foregroundStyle(Palette.amber)
                            Image(systemName: "chevron.right").font(.caption2)
                        }.padding(.vertical,4).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
            if model.isOriginal && !model.isClassic, let rules = database.dmcV1 {
                Panel(title: "EVOLUTION / COLOR Ver.1") {
                    Text("养成由照顾失误、训练、满腹、睡眠打扰和战绩决定；不使用经验升级。")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    ForEach(rules.evolutions) { route in
                        VStack(alignment: .leading,spacing: 4) {
                            Text("\(database.species.first { $0.id == route.from }?.nameSC ?? route.from) → \(database.species.first { $0.id == route.target }?.nameSC ?? route.target)")
                                .font(.caption.bold())
                            Text(route.summary).font(.caption2).foregroundStyle(Palette.muted)
                        }
                    }
                    Text("高阶进化依通算胜率判定：40%起25%、60%起50%、80%起必定。60～69%区间资料存在分歧，待实体机复核。")
                        .font(.caption2).foregroundStyle(Palette.amber)
                    Text("电光暴龙兽＋Ver.2偃月加鲁鲁兽的联展未开放；Alter-S不会通过普通进化获得。")
                        .font(.caption2).foregroundStyle(Palette.muted)
                }
            } else if !model.isOriginal {
            Panel(title: "EVOLUTION / 旧版实验分支") {
                Text("双指缩放、上下左右拖动。以下为本游戏养成路线，并非实体机官方条件。")
                    .font(.caption).foregroundStyle(Palette.muted)
                EvolutionTreeView(species: database.species)
            }
            }
            Text("包含Ver.1的17种养成角色及最终区Alter-S，使用有来源记录的原版彩色角色像素。附近手机通信已接入，双机待验收，联展未开放；部分动作采用已有姿势回退。")
                .font(.caption2).foregroundStyle(Palette.muted)
        }
        }.sheet(item: $selected) { species in
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        if discovery(species.id) == nil && !model.isSandbox {
                            Panel(title: "???") { SpriteThumbnail(id: species.spriteID,size: 120,silhouette: true); Text(model.text(.unknown)) }
                        } else {
                        Panel(title: species.name.uppercased()) {
                            if discovery(species.id) != nil || model.isSandbox { SpeciesPreview(id: species.spriteID,mode: model.display) }
                            else { SpriteThumbnail(id: species.id,size: 120,silhouette: true) }
                            Text("\(species.nameSC) / \(species.nameTC) / \(species.nameJP)").font(.subheadline)
                            Readout(name: "阶段",value: species.stage.rawValue)
                            Readout(name: "种族",value: species.type)
                            Readout(name: "属性",value: species.attribute.rawValue)
                            Readout(name: "必杀技",value: species.specialMove)
                            if !model.isOriginal { Readout(name: "HP / 攻击 / 防御",value: "\(species.stats.hp) / \(species.stats.attack) / \(species.stats.defense)") }
                            if let entry = model.collectionEntries.first(where: { $0.id == species.id }) {
                                Readout(name: model.text(.obtainedCount),value: "\(entry.obtainedCount)")
                                Readout(name: model.text(.firstObtained),value: entry.firstObtained?.formatted(date: .abbreviated,time: .shortened) ?? "旧档未记录")
                            }
                            Readout(name: "首次登场",value: species.firstAppearance ?? "待核验")
                            Text(model.isOriginal ? "Ver.1战斗使用力量与三次命中判定。睡眠和隐藏进化条件依公开资料实现，尚待实体机复核。" : "此页旧版规则数值为实验平衡参数。")
                                .font(.caption).foregroundStyle(Palette.amber)
                            Text("官方资料已核验字段：\(species.verifiedFields.isEmpty ? "待核验" : species.verifiedFields.joined(separator: ", "))")
                                .font(.caption).foregroundStyle(Palette.muted)
                            if let source = species.referenceURL, let url = URL(string: source) { Link("官方角色资料",destination: url) }
                        }
                        if model.isOriginal && !model.isClassic, let rules = model.database?.dmcV1 {
                            Panel(title: "Ver.1 / 条件") {
                                if let stats = rules.roster[species.id] {
                                    Readout(name: "最低体重",value: "\(stats.minimumWeight) g")
                                    Readout(name: "就寝 / 起床",value: stats.sleepHour.map { "\($0):00 / 08:00" } ?? "幼年期Ⅰ不睡眠")
                                    Readout(name: "最大DP",value: "\(stats.maxDP)")
                                }
                                ForEach(rules.evolutions.filter { $0.from == species.id }) { route in
                                    Text("→ \(route.target) · \(route.summary)").font(.caption)
                                }
                                if species.id == "omegamon-alter-s" { Text("需要跨版本通信联展，目前仅作为Quest最终敌人。") }
                            }
                        } else if !model.isOriginal && !species.evolutions.isEmpty {
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
                        }
                    }.pageStyle()
                }.background(Palette.background).navigationTitle(species.name).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { selected = nil } } }
            }
        }
    }
    private func discovery(_ id: String) -> Discovery? {
        model.isSandbox ? model.state?.dex[id] : model.collectionEntries.first(where: { $0.id == id })?.discovery ?? model.state?.dex[id]
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
