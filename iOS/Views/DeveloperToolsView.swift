import SwiftUI
import DigitalWorldCore

struct DeveloperToolsView: View {
    @Environment(\.gameLanguage) private var uiLanguage
    private func l(_ source: String) -> String { GameLocalization.text(source,language: uiLanguage) }

    @ObservedObject var model: WorldViewModel
    @State private var code = ""
    @State private var tab = "species"
    @State private var query = ""
    @State private var itemID = "meat"
    @State private var quantity = "1"
    @State private var values: [DeveloperField:String] = [:]
    @State private var draftPetID: UUID?
    @State private var draftSpecies = ""
    @State private var life = LifeState.alive
    @State private var injured = false
    @State private var sick = false
    @State private var lightsOff = false
    @State private var traited = false
    @State private var evolutionChecked = false
    @FocusState private var focused: String?

    var body: some View {
        VStack(spacing: 16) {
            if !model.developerUnlocked {
                Panel(title: "开发测试 / 访问验证") {
                    SecureField(l("访问码"),text: $code).keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder).focused($focused,equals: "code")
                        .accessibilityIdentifier("developerCode")
                    GameButton(title: "解锁") {
                        if model.unlockDeveloper(code) { code = ""; focused = nil; loadDraft() }
                    }.accessibilityIdentifier("developerUnlock")
                }
            } else if let game = model.state, let database = model.database {
                Panel(title: "开发测试 / 本机存档") {
                    Text(l("修改会写入当前存档。首次修改前自动保留独立备份，可在本页恢复。"))
                        .font(.footnote).foregroundStyle(Palette.muted)
                    Readout(name: "当前伙伴",value: model.species?.nameSC ?? game.pet.speciesID)
                    HStack(spacing: 16) {
                        tabButton("角色",id: "species")
                        tabButton("道具",id: "items")
                        tabButton("数值",id: "stats")
                        tabButton("备份",id: "backup")
                    }
                    Text(l(model.developerNotice)).font(.caption).foregroundStyle(Palette.mint)
                        .accessibilityIdentifier("developerNotice")
                }
                switch tab {
                case "species": species(database)
                case "items": items(game,database)
                case "stats": stats(game)
                default: backup
                }
            }
            if let error = model.developerError {
                Text(l(error)).font(.footnote).foregroundStyle(Palette.amber)
                    .accessibilityIdentifier("developerError")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(l("收起键盘")) { focused = nil } }
        }
    }
    private func tabButton(_ title: String,id: String) -> some View {
        Button(l(title)) {
            focused = nil; query = ""; tab = id
            if id == "stats" { loadDraft() }
        }.font(.subheadline.bold()).foregroundStyle(tab == id ? Palette.mint : Palette.muted)
            .frame(maxWidth: .infinity,minHeight: 36).accessibilityIdentifier("developer-tab-\(id)")
    }
    private func search(_ title: String) -> some View {
        TextField(l(title),text: $query).textFieldStyle(.roundedBorder)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .focused($focused,equals: "search").accessibilityIdentifier("developerSearch")
    }
    private func species(_ database: ContentDatabase) -> some View {
        Panel(title: "角色 / \(database.species.count) 种") {
            search("搜索角色名称或ID")
            Text(l("直接指定当前伙伴，包括仅用于关卡的角色；该操作属于开发测试。"))
                .font(.caption).foregroundStyle(Palette.muted)
            ForEach(database.species.filter { s in query.isEmpty || [s.id,s.name,s.nameSC,s.nameJP].contains { $0.localizedCaseInsensitiveContains(query) } }) { s in
                HStack {
                    SpriteThumbnail(id: s.id,size: 48)
                    VStack(alignment: .leading) {
                        Text(l(s.nameSC)).font(.headline)
                        Text(l(s.name)).font(.caption).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button(l("使用")) { focused = nil; _ = model.developer(.selectSpecies(s.id)) }
                        .buttonStyle(.bordered).accessibilityIdentifier("developer-species-\(s.id)")
                }
            }
        }
    }
    private func items(_ game: GameState,_ database: ContentDatabase) -> some View {
        let catalog = DeveloperEngine.itemCatalog(database: database,state: game)
        return Panel(title: "道具 / 库存测试") {
            search("搜索道具名称或ID")
            ForEach(catalog.keys.sorted().filter { query.isEmpty || $0.localizedCaseInsensitiveContains(query) || catalog[$0]!.localizedCaseInsensitiveContains(query) },id: \.self) { id in
                Button { itemID = id; focused = nil } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(l(catalog[id] ?? id))
                            Text(l(id)).font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        Text(l("库存 \(game.inventory[id,default: 0])")).font(.caption)
                        Image(systemName: itemID == id ? "checkmark.circle.fill" : "circle")
                    }.frame(maxWidth: .infinity,minHeight: 36).contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Palette.mint).accessibilityIdentifier("developer-item-\(id)")
                    .accessibilityValue(l(itemID == id ? "已选择" : "未选择"))
            }
            TextField(l("道具ID（也可输入自定义ID）"),text: $itemID)
                .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($focused,equals: "itemID").accessibilityIdentifier("developerItemID")
            TextField(l("发放数量"),text: $quantity).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                .focused($focused,equals: "quantity").accessibilityIdentifier("developerItemQuantity")
            GameButton(title: "发放道具") {
                focused = nil
                guard let count = Int(quantity) else { model.developerError = "请输入整数数量"; return }
                _ = model.developer(.grantItem(itemID,count))
            }.accessibilityIdentifier("developerGrantItem")
            Text(l("肉和蛋白质在原味玩法中不限量；其他道具或自定义ID只设置库存，不会自动增加尚未实现的效果。"))
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }
    private func stats(_ game: GameState) -> some View {
        Panel(title: "数值 / 当前伙伴") {
            search("搜索数值名称")
            HStack {
                Button(l("重新载入当前数值")) { loadDraft() }
                Spacer()
                Button(l("保存数值")) { saveDraft() }.buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("developerSaveStats")
            }
            Text(l("保存会写回全部草稿数值；需要最新计时可先重新载入。"))
                .font(.caption).foregroundStyle(Palette.muted)
            ForEach(DeveloperField.available(original: model.isOriginal).filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.rawValue.localizedCaseInsensitiveContains(query) }) { field in
                VStack(alignment: .leading,spacing: 6) {
                    let range = field.range(original: model.isOriginal)
                    Text(l("\(field.title) · \(range.lowerBound)…\(range.upperBound)")).font(.caption).foregroundStyle(Palette.muted)
                    TextField(l(field.title),text: Binding(get: { values[field] ?? "" },set: { values[field] = $0 }))
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        .focused($focused,equals: field.rawValue).accessibilityIdentifier("developer-field-\(field.rawValue)")
                }
            }
            if query.isEmpty {
                Picker(l("生命状态"),selection: $life) {
                    Text(l("成长中")).tag(LifeState.alive)
                    Text(l("Cold暂停")).tag(LifeState.frozen)
                    Text(l("死亡")).tag(LifeState.dead)
                }.pickerStyle(.segmented)
                Toggle(l("受伤"),isOn: $injured)
                Toggle(l("关灯"),isOn: $lightsOff)
                if game.pet.dmc != nil {
                    Toggle(l("强力蛋加成"),isOn: $traited)
                    Toggle(l("本阶段已判定进化"),isOn: $evolutionChecked)
                } else { Toggle(l("生病"),isOn: $sick) }
                Text(l("胜利不可超过战斗，训练成功不可超过尝试，当前DP不可超过DP上限。正常进化会恢复新形态的默认战斗参数。"))
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
    private var backup: some View {
        Panel(title: "备份 / 调试前存档") {
            Text(l("每次解锁后的首次成功修改前保留一次快照；后续发放和数值修改不会轮换掉这份快照。"))
                .font(.footnote).foregroundStyle(Palette.muted)
            if let url = model.developerBackupURL {
                ShareLink(l("导出调试前备份"),item: url)
                GameButton(title: "恢复调试前存档") { model.restoreDeveloperBackup(); loadDraft() }
                    .accessibilityIdentifier("developerRestore")
            } else { Text(l("尚无调试修改备份")) }
            Button(l("锁定开发测试")) { model.lockDeveloper(); code = "" }
                .accessibilityIdentifier("developerLock")
        }
    }
    private func loadDraft() {
        guard let game = model.state, let database = model.database else { return }
        draftPetID = game.pet.id; draftSpecies = game.pet.speciesID
        values = Dictionary(uniqueKeysWithValues: DeveloperField.available(original: model.isOriginal).map { ($0,String((try? $0.value(pet: game.pet,database: database)) ?? 0)) })
        life = game.pet.life; injured = game.pet.stats.injured; sick = game.pet.stats.sick
        lightsOff = game.pet.lightsOff; traited = game.pet.dmc?.traited ?? false
        evolutionChecked = game.pet.dmc?.evolutionChecked ?? false
    }
    private func saveDraft() {
        focused = nil
        guard let game = model.state, game.pet.id == draftPetID, game.pet.speciesID == draftSpecies else {
            model.developerError = "伙伴已变化，请重新载入当前数值"; return
        }
        var edit = DeveloperPetEdit(pet: game.pet)
        for field in DeveloperField.available(original: model.isOriginal) {
            guard let raw = values[field], let value = Int(raw) else { model.developerError = "\(field.title)须为整数"; return }
            edit.values[field] = value
        }
        edit.life = life; edit.injured = injured; edit.sick = sick; edit.lightsOff = lightsOff
        edit.traited = traited; edit.evolutionChecked = evolutionChecked
        if model.developer(.edit(edit)) { loadDraft() }
    }
}
