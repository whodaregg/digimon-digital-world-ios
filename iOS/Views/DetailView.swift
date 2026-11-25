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
                case .developer: DeveloperToolsView(model: model)
                case .call:
                    Panel(title: "CALL / 养成呼叫") {
                        Text(model.callMessage).font(.headline)
                        Text("空腹或力量呼叫须在10分钟内回应；睡眠呼叫须在1小时内关灯。")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }
                case .clock:
                    Panel(title: "CLOCK / 时钟") {
                        TimelineView(.periodic(from: .now,by: 1)) { context in
                            Text(context.date,format: .dateTime.hour().minute().second())
                                .font(.system(size: 36,weight: .bold,design: .monospaced))
                        }
                        Text(model.state?.homeTimeZone ?? "").font(.caption)
                    }
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
                if !model.isOriginal { Readout(name: "性格",value: game.pet.personality) }
            }
            if let care = game.pet.dmc {
                Panel(title: "CARE / Ver.1") {
                    HeartReadout(name: "饱食",value: care.hungerHearts)
                    HeartReadout(name: "力量",value: care.strengthHearts)
                    HeartReadout(name: "努力",value: care.effortHearts)
                    Readout(name: "DP",value: "\(game.pet.stats.dp)")
                    Readout(name: "战斗 / 通算胜率",value: "\(game.pet.stats.battles) / \(Int(game.pet.stats.winRate*100))%")
                    Readout(name: "本阶段训练",value: "\(care.stageTrainings)")
                    Readout(name: "本阶段照顾失误",value: "\(care.stageMistakes)")
                    Readout(name: "本阶段满腹 / 睡眠打扰",value: "\(care.overfeeds) / \(care.sleepDisturbances)")
                    Readout(name: "废物",value: "\(game.pet.stats.waste)")
                    Readout(name: "伤势",value: game.pet.stats.injured ? "需继续治疗" : "无伤")
                }
            } else {
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
                Text(model.isOriginal ? "肉恢复1颗饱食心、增重1g；蛋白质恢复1颗力量心、增重2g，每4份恢复1 DP。满腹与蛋白质过量会影响养成。" : "肉与蛋白质不限量供应；其他食物来自旧版实验玩法。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                ForEach(database.foods.filter { rule.foods.contains($0.id) }) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.id == "meat" ? "fork.knife.circle" : item.id == "protein" ? "bolt.circle" : "leaf.circle")
                            .font(.title).foregroundStyle(Palette.mint).frame(width: 40)
                        VStack(alignment: .leading,spacing: 4) {
                            Text(item.name).font(.headline)
                            Text(model.isOriginal ? (item.id == "meat" ? "饱食＋1心 · 体重＋1g" : "力量＋1心 · 体重＋2g") : "饱食 +\(item.fullness)  力量 +\(item.strength)  体重 +\(item.weight)g")
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
                Text(model.isOriginal ? "依角色就寝时间自动入睡，08:00醒来。连续睡眠8小时恢复全部DP；睡眠仍计入进化时间。Cold暂停成长，备份交换只保存一只伙伴。" : "旧版实验规则：21:00–07:00自然睡眠，手动休息恢复能量。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Readout(name: "养成时区",value: game.homeTimeZone)
                Toggle("关灯",isOn: Binding(get: { model.state?.pet.lightsOff ?? false },set: { model.care(.lights($0)) }))
                if !model.isOriginal { Toggle("手动休息",isOn: Binding(get: { model.state?.pet.manualRest ?? false },set: { model.care(.rest($0)) })) }
                Toggle("冷冻成长",isOn: Binding(get: { model.state?.pet.life == .frozen },set: { model.care(.freeze($0)) }))
                    .disabled(game.pet.life == .dead)
                if model.isOriginal {
                    GameButton(title: game.dmc?.backupPetID == nil ? "备份当前伙伴并开始新蛋" : "与备份伙伴交换") { model.swapBackup() }
                        .disabled(game.pet.isEgg || game.pet.life == .dead)
                    Text("交换后饱食与力量归零；体重、努力及成长记录保留。")
                        .font(.caption).foregroundStyle(Palette.muted)
                } else { Metric(name: "能量",value: game.pet.stats.energy,color: Palette.amber) }
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
                        else if !model.isOriginal { Button("切换") { model.care(.selectPet(pet.id)) }.buttonStyle(.bordered) }
                        else { Text(pet.id == game.dmc?.backupPetID ? "备份" : "历史").font(.caption) }
                    }.padding(.vertical,6)
                }
                if game.pet.life == .dead {
                    ForEach(database.eggs.filter { (try? database.device(game.deviceID).eggs.contains($0.id)) == true }) { egg in
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
                displayChoice("复古彩色",mode: .color)
                displayChoice("高级彩色",mode: .advanced)
                displayChoice("经典灰绿色 LCD",mode: .lcd)
                Text("新游戏默认彩色。彩色模式显示原图配色，高级彩色加入动态光点；经典模式显示灰绿色单色像素。选择会随存档保存。")
                    .font(.footnote).foregroundStyle(Palette.muted)
                PetScreen(model: model).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let device = game.dmc {
                Panel(title: "BACKGROUND / 屏幕背景") {
                    Picker("已解锁背景",selection: Binding(get: { device.selectedBackground },set: { model.selectBackground($0) })) {
                        ForEach(device.backgrounds.sorted(),id: \.self) { id in Text(backgroundName(id)).tag(id) }
                    }.pickerStyle(.menu)
                    Text("通关区域1、4、F可解锁背景主题；养成真熊仔兽另有纪念主题。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            } else {
                Panel(title: "Ver.1 / 开始原味养成") {
                    Text("当前为旧版实验档。开始Ver.1前会单独保存完整旧档，可随时导入恢复。")
                        .font(.footnote)
                    GameButton(title: "备份旧档并开始 Ver.1") { model.startOriginalProfile() }
                }
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
                if let previous = model.previousProfileBackupURL {
                    ShareLink("导出切换前档案",item: previous)
                    Button("恢复切换前档案") { model.restorePreviousProfile() }
                        .accessibilityIdentifier("restorePreviousProfile")
                    Text("恢复前也会保存当前档案；养成时间继续按各档记录结算。")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Text("每次操作后原子写入；保留上一次有效备份。iCloud、联机、Watch 与系统小组件属于后续阶段。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }
    private func backgroundName(_ id: String) -> String {
        ["grasslands":"草原","office":"办公室","grid":"网格","dmc-logo":"COLOR标志","box-art":"包装主题","25th-anniversary":"25周年"][id] ?? id
    }
    private func displayChoice(_ title: String,mode: DisplayMode) -> some View {
        Button { model.settings { $0.display = mode } } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: model.display == mode ? "checkmark.circle.fill" : "circle")
            }.frame(minHeight: 32).contentShape(Rectangle())
                .foregroundStyle(model.display == mode ? Palette.mint : Palette.muted)
        }.buttonStyle(.plain).accessibilityIdentifier("display-mode-\(mode.rawValue)")
            .accessibilityValue(model.display == mode ? "已选择" : "未选择")
    }
    @ViewBuilder private var devices: some View {
        if let database = model.database {
            Panel(title: "ACTIVE / 可游玩") {
                Text("Digital Monster COLOR Ver.1").font(.headline).foregroundStyle(Palette.mint)
                Text(database.devices[0].notes).font(.footnote).foregroundStyle(Palette.muted)
                Text("肉与蛋白质、A/B五次攻击训练、四心养成、Cold与一只备份、8区固定顺序Quest。隐藏参数来自有出处的社区实测，仍待实体机逐项复核。")
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
