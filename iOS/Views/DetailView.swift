import SwiftUI
import DigitalWorldCore

struct DetailView: View {
    let page: WorldPage
    @ObservedObject var model: WorldViewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch page {
                case .status: status
                case .food: food
                case .train: TrainingView(model: model)
                case .battle: BattleView(model: model)
                case .sleep: sleep
                case .adventure: AdventureView(model: model)
                case .digidex: DigidexView(model: model)
                case .storage: storage
                case .settings: settings
                case .devices: devices
                }
            }.pageStyle()
        }.background(Palette.background)
    }
    @ViewBuilder private var status: some View {
        if let game = model.state {
            Panel(title: "PARTNER / \(model.species?.name.uppercased() ?? "EGG")") {
                PetScreen(model: model).clipShape(RoundedRectangle(cornerRadius: 8))
                Readout(name: "状态",value: game.pet.isEgg ? "孵化中" : game.pet.life.rawValue)
                Readout(name: "阶段",value: game.pet.isEgg ? "Digi-Egg" : model.species?.stage.rawValue ?? "")
                Readout(name: "年龄",value: "\(game.pet.activeMinutes/1440) 天 \(game.pet.activeMinutes%1440/60) 小时")
                Readout(name: "体重",value: "\(game.pet.stats.weight) g")
                Readout(name: "属性",value: model.species?.attribute.rawValue ?? "unknown")
                Readout(name: "性格",value: game.pet.personality)
            }
            Panel(title: "CARE / 养成数值") {
                Metric(name: "饱食度",value: game.pet.stats.fullness)
                Metric(name: "力量",value: game.pet.stats.strength)
                Metric(name: "幸福",value: game.pet.stats.happiness)
                Metric(name: "能量",value: game.pet.stats.energy,color: Palette.amber)
                Metric(name: "健康",value: game.pet.stats.health)
                Metric(name: "体力",value: game.pet.stats.stamina)
                Metric(name: "亲密度",value: game.pet.stats.bond)
                Metric(name: "忠诚度",value: game.pet.stats.loyalty)
                Readout(name: "DP",value: "\(game.pet.stats.dp)")
                Readout(name: "训练成功 / 尝试",value: "\(game.pet.stats.training) / \(game.pet.stats.trainingAttempts)")
                Readout(name: "喂食次数",value: "\(game.pet.stats.meals)")
                Readout(name: "战斗 / 胜率",value: "\(game.pet.stats.battles) / \(Int(game.pet.stats.winRate*100))%")
                Readout(name: "照顾失误",value: "\(game.pet.stats.mistakes)")
                Readout(name: "生病 / 受伤次数",value: "\(game.pet.stats.illnesses) / \(game.pet.stats.injuries)")
                Readout(name: "环境废物",value: "\(game.pet.stats.waste)")
                Readout(name: "当前疾病 / 受伤",value: "\(game.pet.stats.sick ? "生病" : "无疾病") / \(game.pet.stats.injured ? "受伤" : "无伤")")
            }
            Panel(title: "JOURNAL / 成长日志") {
                ForEach(game.pet.history.reversed()) { event in
                    HStack(alignment: .top) {
                        Text(event.date,format: .dateTime.month().day().hour().minute())
                            .font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.muted)
                        Text(event.message).font(.caption)
                    }
                }
                Text("保留最近 300 条详细事件及完整进化顺序。")
                    .font(.caption2).foregroundStyle(Palette.muted)
            }
        }
    }
    @ViewBuilder private var food: some View {
        if let game = model.state, let database = model.database,
           let rule = try? database.device(game.deviceID) {
            Panel(title: "FEED / 食物") {
                Text("肉与蛋白质不限量供应。其他食物来自探索或对战；过量喂食会损害健康。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                ForEach(database.foods.filter { rule.foods.contains($0.id) }) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.id == "meat" ? "fork.knife.circle" : item.id == "protein" ? "bolt.circle" : "leaf.circle")
                            .font(.title).foregroundStyle(Palette.mint).frame(width: 40)
                        VStack(alignment: .leading,spacing: 4) {
                            Text(item.name).font(.headline)
                            Text("饱食 +\(item.fullness)  力量 +\(item.strength)  体重 +\(item.weight)g")
                                .font(.system(size: 10,design: .monospaced)).foregroundStyle(Palette.muted)
                            Text(["meat","protein"].contains(item.id) ? "供应充足" : "库存 \(game.inventory[item.id,default: 0])")
                                .font(.caption2).foregroundStyle(Palette.amber)
                        }
                        Spacer(minLength: 0)
                        Button("喂食") { model.care(.feed(item.id)) }.buttonStyle(.bordered)
                            .disabled(game.pet.isEgg || game.pet.life != .alive || game.pet.sleeping ||
                                      (!["meat","protein"].contains(item.id) && game.inventory[item.id,default: 0] == 0))
                            .accessibilityIdentifier("feed-\(item.id)")
                    }.padding(.vertical,6)
                }
            }
            Panel(title: "PARTNER") { PetScreen(model: model).clipShape(RoundedRectangle(cornerRadius: 8)) }
        }
    }
    @ViewBuilder private var sleep: some View {
        if let game = model.state {
            Panel(title: "SLEEP / \(game.pet.sleeping ? "休息中" : "清醒")") {
                Text("当前测试规则的自然睡眠为 21:00–07:00，采用创建存档时的固定时区。手动休息可恢复能量，睡眠时请关灯。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Readout(name: "养成时区",value: game.homeTimeZone)
                Toggle("关灯",isOn: Binding(get: { model.state?.pet.lightsOff ?? false },set: { model.care(.lights($0)) }))
                Toggle("手动休息",isOn: Binding(get: { model.state?.pet.manualRest ?? false },set: { model.care(.rest($0)) }))
                Toggle("冷冻成长",isOn: Binding(get: { model.state?.pet.life == .frozen },set: { model.care(.freeze($0)) }))
                    .disabled(game.pet.life == .dead)
                Metric(name: "能量",value: game.pet.stats.energy,color: Palette.amber)
                PetScreen(model: model).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    @ViewBuilder private var storage: some View {
        if let game = model.state, let database = model.database {
            Panel(title: "STORAGE / \(game.pets.count) 条养成档案") {
                Text("冷冻会暂停年龄与养成消耗。死亡后可从数码蛋开始新生命，图鉴和历史仍然保留。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                ForEach(game.pets) { pet in
                    let species = try? database.species(pet.speciesID)
                    HStack {
                        SpriteThumbnail(id: pet.speciesID,size: 48)
                        VStack(alignment: .leading,spacing: 4) {
                            Text(pet.isEgg ? "Digi-Egg" : species?.name ?? pet.speciesID).font(.headline)
                            Text("\(pet.life.rawValue.uppercased()) · \(pet.activeMinutes/1440) DAYS").font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.muted)
                            Text(pet.evolutionHistory.joined(separator: " → ")).font(.caption2).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        if pet.id == game.activePetID { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.mint) }
                        else { Button("查看") { model.care(.selectPet(pet.id)) }.buttonStyle(.bordered) }
                    }.padding(.vertical,6)
                }
                if game.pet.life == .dead {
                    ForEach(database.eggs) { egg in
                        let unlocked = game.dex.values.filter { $0 == .raised }.count >= egg.requiredRaised
                        GameButton(title: "\(egg.name) · \(unlocked ? "重新孵化" : "需养成 \(egg.requiredRaised) 种角色")") { model.care(.rebirth(egg.id)) }
                            .disabled(!unlocked)
                    }
                } else {
                    GameButton(title: game.pet.life == .frozen ? "恢复成长" : "冷冻当前伙伴") { model.care(.freeze(game.pet.life != .frozen)) }
                }
                if let url = model.exportURL { ShareLink("导出完整存档",item: url) }
            }
        }
    }
    @ViewBuilder private var settings: some View {
        if let game = model.state {
            Panel(title: "DISPLAY / 像素显示") {
                Picker("显示模式",selection: Binding(get: { model.display },set: { value in model.settings { $0.display = value } })) {
                    Text("Classic LCD").tag(DisplayMode.lcd)
                    Text("Retro Color").tag(DisplayMode.color)
                    Text("Advanced Pixel").tag(DisplayMode.advanced)
                }.pickerStyle(.menu)
                Text("LCD 使用单色像素；彩色模式增加场景层次；高级模式加入动态光点。素材均以最近邻方式采样。")
                    .font(.footnote).foregroundStyle(Palette.muted)
            }
            Panel(title: "FEEDBACK / 声音与触觉") {
                Toggle("电子按键音",isOn: Binding(get: { model.state?.settings.sound ?? true },set: { v in model.settings { $0.sound = v } }))
                Toggle("触觉反馈",isOn: Binding(get: { model.state?.settings.haptics ?? true },set: { v in model.settings { $0.haptics = v } }))
                Text("按键音遵循 iPhone 静音开关。") .font(.caption).foregroundStyle(Palette.muted)
            }
            Panel(title: "REMINDERS / 本地提醒") {
                Toggle("允许养成提醒",isOn: Binding(get: { game.settings.notifications },set: { model.setNotifications($0) }))
                Stepper("安静开始 \(game.settings.quietStart):00",value: Binding(get: { game.settings.quietStart },set: { v in model.settings { $0.quietStart = v } }),in: 0...23)
                Stepper("安静结束 \(game.settings.quietEnd):00",value: Binding(get: { game.settings.quietEnd },set: { v in model.settings { $0.quietEnd = v } }),in: 0...23)
                Text("通知为辅助提醒，养成结算独立于通知和后台运行。系统可能延迟通知。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            Panel(title: "SAVE / 本地自动存档") {
                Readout(name: "存档格式",value: "v\(game.schemaVersion)")
                Readout(name: "内容数据库",value: "v\(game.databaseVersion)")
                Readout(name: "最后结算",value: game.lastTick.formatted(date: .abbreviated,time: .shortened))
                if let url = model.exportURL { ShareLink("导出备份",item: url) }
                BackupRestoreView(model: model)
                Text("每次操作后原子写入；保留上一次有效备份。iCloud、联机、Watch 与系统小组件属于后续阶段。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
    @ViewBuilder private var devices: some View {
        if let database = model.database {
            Panel(title: "ACTIVE / 可游玩") {
                Text("1997 LAB · ULTIMATE").font(.headline).foregroundStyle(Palette.mint)
                Text(database.devices[0].notes).font(.footnote).foregroundStyle(Palette.muted)
                Text("肉与蛋白质、时机训练、离线 PVE、冷冻与原创探索规则已接入。")
                    .font(.footnote)
            }
            Panel(title: "ORIGINAL / 资料核验队列") {
                Text("以下为待开发目录，尚不支持切换。每种机型需独立核实说明书、角色名单和养成规则。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                ForEach(database.devices.filter { !$0.enabled }) { device in
                    HStack {
                        Text(device.name).font(.system(.caption,design: .monospaced))
                        Spacer()
                        Text("待核验").font(.caption2).foregroundStyle(Palette.amber)
                    }.padding(.vertical,5)
                }
            }
        }
    }
}
