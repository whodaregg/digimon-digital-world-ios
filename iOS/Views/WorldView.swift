import SwiftUI
import DigitalWorldCore

enum WorldPage: String, Identifiable, CaseIterable {
    case status, food, train, battle, sleep, adventure, digidex, storage, settings, devices, call, clock, developer
    var id: String { rawValue }
    var title: String {
        switch self {
        case .status: return "伙伴状态"
        case .food: return "喂食"
        case .train: return "训练"
        case .battle: return "Quest 闯关"
        case .sleep: return "睡眠与休息"
        case .adventure: return "Quest 区域"
        case .digidex: return "DIGIDEX"
        case .storage: return "伙伴档案"
        case .settings: return "设置"
        case .devices: return "机型与规则"
        case .call: return "养成呼叫"
        case .clock: return "时钟"
        case .developer: return "开发测试"
        }
    }
}

struct WorldView: View {
    @ObservedObject var model: WorldViewModel
    @State private var page: WorldPage?
    @State private var selected: Int?
    @Environment(\.scenePhase) private var phase
    private let timer = Timer.publish(every: 1,on: .main,in: .common).autoconnect()
    private var actions: [(String,String,String)] {
        if model.isOriginal { return [
            ("STATUS","状态","chart.bar.xaxis"), ("FOOD","喂食","fork.knife"),
            ("TRAIN","训练","scope"), ("BATTLE","对战","bolt.shield"),
            ("CLEAN","清洁","sparkles"), ("SLEEP","睡眠","moon.zzz"),
            ("MEDICAL","医疗","cross.case"), ("CALL","呼叫","bell")
        ] }
        return [
        ("STATUS","状态","chart.bar.xaxis"), ("FOOD","喂食","fork.knife"),
        ("TRAIN","训练","scope"), ("BATTLE","对战","bolt.shield"),
        ("CLEAN","清洁","sparkles"), ("MEDICAL","医疗","cross.case"),
        ("SLEEP","睡眠","moon.zzz"), ("ADVENTURE","冒险","map"),
        ("DIGIDEX","图鉴","square.grid.2x2"), ("STORAGE","档案","archivebox"),
        ("SETTINGS","设置","slider.horizontal.3"), ("DIGIVICE","机型","gamecontroller")
        ]
    }
    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if let failure = model.fatalError {
                VStack(spacing: 20) {
                    Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle).foregroundStyle(Palette.amber)
                    Text("数据暂时无法载入").font(.title2.bold())
                    Text(failure).foregroundStyle(Palette.muted)
                    Text("已保留原存档。请检查存储空间或恢复文件后重新启动。为保护养成记录，此时不会创建新存档。")
                        .font(.subheadline)
                    if model.database != nil { BackupRestoreView(model: model) }
                }.padding(28)
            } else if model.state != nil {
                home
            } else if model.database != nil {
                welcome
            }
        }
        .onReceive(timer) { _ in if phase == .active { model.refresh() } }
        .onChange(of: model.state?.deviceID) { _, _ in selected = nil; if page != .developer { page = nil } }
        .onChange(of: phase) { _, value in if value != .active { model.lockDeveloper() } }
        .sheet(item: $page) { value in
            NavigationStack {
                DetailView(page: value,model: model)
                    .background(Palette.background)
                    .navigationTitle(value.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("完成") { model.cancelTrainingIfNeeded(value); page = nil } }
                    }
            }.presentationDragIndicator(.visible)
                .onDisappear {
                    if model.state?.training != nil { model.cancelTraining() }
                    model.lockDeveloper()
                }
        }
        .alert("提示",isPresented: Binding(get: { model.alert != nil },set: { if !$0 { model.alert = nil } })) {
            Button("知道了",role: .cancel) { model.alert = nil }
        } message: { Text(model.alert ?? "") }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 30) {
                header
                Text("一个小小的屏幕。\n一个持续生长的世界。")
                    .font(.system(.largeTitle,design: .monospaced,weight: .bold)).foregroundStyle(Palette.mint)
                Panel(title: "01 / CHOOSE YOUR BEGINNING") {
                    HStack {
                        Image(systemName: "circle.dotted.circle.fill").font(.system(size: 68)).foregroundStyle(Palette.mint)
                            .frame(width: 100,height: 100).background(Palette.background,in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading,spacing: 8) {
                            Text("始源之蛋").font(.title2.bold())
                            Text("8 秒孵化 · 幼年期 I").font(.caption).foregroundStyle(Palette.muted)
                            Text("Digital Monster COLOR Ver.1").font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.amber)
                        }
                    }
                    Text("从一枚蛋开始。喂食、清洁、互动训练，让你的照顾方式决定它的成长。离开后时间仍然流逝。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    GameButton(title: "孵化这枚数码蛋") { model.start(eggID: "dmc-v1-egg") }
                        .accessibilityIdentifier("startHatching")
                }
                Panel(title: "当前内容 / 开发中") {
                    Text("以 Digital Monster COLOR Ver.1 为基准：四心养成、A/B 上下段训练、8区顺序闯关。原版角色像素，默认彩色；设置可切换经典灰绿色 LCD。")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    Button("查看机型与规则状态") { page = .devices }
                }
                Text("OFFLINE FIRST  ·  NO ADS  ·  REAL TIME")
                    .font(.system(.caption2,design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
            }.pageStyle().padding(.top,20)
        }
    }

    private var home: some View {
        ScrollView {
            VStack(spacing: 22) {
                header
                if let state = model.state {
                    device(state)
                    if let care = state.pet.dmc {
                        VStack(spacing: 10) {
                            HeartReadout(name: "饱食",value: care.hungerHearts)
                            HeartReadout(name: "力量",value: care.strengthHearts)
                            HeartReadout(name: "努力",value: care.effortHearts)
                        }
                    } else {
                    HStack(spacing: 18) {
                        Metric(name: "饱食 FULL",value: state.pet.stats.fullness)
                        Metric(name: "能量 ENERGY",value: state.pet.stats.energy,color: Palette.amber)
                        Metric(name: "健康 HEALTH",value: state.pet.stats.health)
                    }
                    }
                    HStack(spacing: 10) {
                        Circle().fill(Palette.mint).frame(width: 5,height: 5)
                        Text(model.message).font(.system(.caption,design: .monospaced)).foregroundStyle(Palette.muted).lineLimit(2)
                        Spacer(minLength: 0)
                    }.frame(minHeight: 30).accessibilityIdentifier("worldMessage")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(),spacing: 9),count: 4),spacing: 10) {
                        ForEach(actions.indices,id: \.self) { index in
                            Button { selected = index; activate(index) } label: {
                                VStack(spacing: 7) {
                                    Image(systemName: actions[index].2).font(.system(size: 20,weight: .light))
                                    Text(actions[index].0).font(.system(size: 9,weight: .bold,design: .monospaced)).lineLimit(1).minimumScaleFactor(0.65)
                                }.frame(maxWidth: .infinity,minHeight: 65)
                                    .foregroundStyle(actions[index].0 == "CALL" && model.hasCall ? Palette.amber : selected == index ? Palette.mint : Palette.muted)
                                    .background(selected == index ? Palette.mint.opacity(0.08) : Palette.panel,in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected == index ? Palette.mint.opacity(0.65) : Palette.line,lineWidth: 1))
                            }.buttonStyle(.plain).accessibilityLabel(actions[index].0 == "CALL" ? (model.hasCall ? "养成呼叫已点亮" : "养成呼叫未点亮") : actions[index].1)
                                .accessibilityIdentifier("action-\(actions[index].0)")
                                .disabled(model.isOriginal && actions[index].0 == "CALL")
                        }
                    }
                    if model.isOriginal {
                        if model.hasCall { Text(model.callMessage).font(.caption).foregroundStyle(Palette.amber) }
                        HStack {
                            utility("DIGIDEX","图鉴",page: .digidex)
                            utility("STORAGE","档案",page: .storage)
                            utility("SETTINGS","设置",page: .settings)
                            utility("DIGIVICE","机型",page: .devices)
                        }
                    }
                    hardwareButtons
                    HStack {
                        Text("LOCAL SAVE / AUTO").font(.system(size: 9,design: .monospaced))
                        Spacer()
                        Text(state.developerModifiedAt != nil ? "开发测试档" : model.isOriginal ? "v0.4.0 · COLOR Ver.1" : "旧版实验规则").font(.system(size: 9,design: .monospaced))
                    }.foregroundStyle(Palette.muted.opacity(0.7))
                }
            }.pageStyle()
        }.accessibilityIdentifier("worldHome")
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading,spacing: 3) {
                Text("DIGIMON").font(.system(size: 23,weight: .black,design: .monospaced)).tracking(3).foregroundStyle(Palette.mint)
                    .contentShape(Rectangle()).onLongPressGesture(minimumDuration: 2) {
                        model.lockDeveloper(); page = .developer
                    }.accessibilityIdentifier("developer-entry")
                Text("D I G I T A L   W O R L D").font(.system(size: 9,weight: .medium,design: .monospaced)).foregroundStyle(Palette.muted)
            }
            Spacer()
            VStack(alignment: .trailing,spacing: 4) {
                TimelineView(.periodic(from: .now,by: 1)) { context in
                    Text(context.date,style: .time).font(.system(.subheadline,design: .monospaced,weight: .semibold))
                }
                Text("● OFFLINE READY").font(.system(size: 8,design: .monospaced)).foregroundStyle(Palette.mint)
            }
        }.padding(.vertical,12)
    }

    private func device(_ state: GameState) -> some View {
        VStack(spacing: 14) {
            HStack {
                bolt; Spacer(); Text("D I G I T A L   M O N S T E R").font(.system(size: 9,weight: .bold,design: .monospaced)).foregroundStyle(Palette.muted); Spacer(); bolt
            }
            HStack {
                Text(model.display == .lcd ? "CLASSIC LCD" : model.isOriginal ? "COLOR Ver.1" : "COLOR LAB").font(.system(size: 10,weight: .black,design: .monospaced)).foregroundStyle(Palette.amber)
                Spacer()
                Text(state.pet.life == .frozen ? "❄ PAUSED" : state.pet.life == .dead ? "MEMORY" : state.pet.sleeping ? "SLEEPING" : "● LIVE")
                    .font(.system(size: 9,weight: .bold,design: .monospaced)).foregroundStyle(Palette.mint)
            }
            VStack(spacing: 0) {
                HStack {
                    Text(state.pet.isEgg ? "DIGI-EGG" : model.species?.name.uppercased() ?? "UNKNOWN")
                    Spacer()
                    Text(state.pet.isEgg ? "HATCHING" : "\(state.pet.activeMinutes / 1440) D · \(model.species?.stage.rawValue.uppercased() ?? "")")
                }.font(.system(size: 9,weight: .bold,design: .monospaced)).foregroundStyle(Palette.screenInk(model.display))
                    .padding(.horizontal,12).padding(.top,10).background(Palette.screenSurface(model.display))
                PetScreen(model: model)
                HStack {
                    Text(state.pet.isEgg ? (model.isOriginal ? "破壳倒计时 \(model.hatchRemainingSeconds) SEC" : "破壳倒计时 \(model.hatchRemainingMinutes) MIN") : "\(state.pet.stats.weight) g")
                    Spacer()
                    Text("DP \(state.pet.stats.dp)")
                }.font(.system(size: 8,weight: .bold,design: .monospaced)).foregroundStyle(Palette.screenInk(model.display))
                    .padding(10).background(Palette.screenSurface(model.display))
            }.clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(9).background(Color.black.opacity(0.5),in: RoundedRectangle(cornerRadius: 12))
            HStack {
                bolt; Spacer()
                ForEach(0..<5) { _ in Capsule().fill(Palette.line).frame(width: 3,height: 9) }
                Spacer(); bolt
            }
        }.padding(18)
            .background(LinearGradient(colors: [Color(red: 0.16,green: 0.21,blue: 0.23),Palette.panel],startPoint: .topLeading,endPoint: .bottomTrailing),in: RoundedRectangle(cornerRadius: 27))
            .overlay(RoundedRectangle(cornerRadius: 27).stroke(Palette.line,lineWidth: 2))
    }
    private var bolt: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.3)).frame(width: 10,height: 10)
            Rectangle().fill(Palette.muted.opacity(0.5)).frame(width: 5,height: 1).rotationEffect(.degrees(-45))
        }
    }
    private var hardwareButtons: some View {
        HStack(spacing: 35) {
            hardware("A","选择") { selected = selected.map { ($0+1)%(model.isOriginal ? 7 : actions.count) } ?? 0; model.feedbackTap() }
            hardware("B","确认 / 时钟") { if let selected { activate(selected) } else { page = .clock } }
            hardware("C","返回") { if page != nil { page = nil } else { selected = nil }; model.feedbackTap() }
        }.padding(.vertical,5)
    }
    private func hardware(_ label: String,_ caption: String,action: @escaping () -> Void) -> some View {
        VStack(spacing: 7) {
            Button(action: action) {
                Text(label).font(.system(size: 19,weight: .bold,design: .monospaced))
                    .foregroundStyle(label == "B" ? Palette.background : Palette.mint)
                    .frame(width: 58,height: 48)
                    .background(label == "B" ? Palette.mint : Palette.panel,in: Capsule())
                    .overlay(Capsule().stroke(Palette.line,lineWidth: 1))
                    .shadow(color: .black.opacity(0.5),radius: 0,x: 0,y: 4)
            }.buttonStyle(.plain).accessibilityLabel("\(label)键，\(caption)").accessibilityIdentifier("hardware-\(label)")
            Text(caption).font(.system(size: 9,design: .monospaced)).foregroundStyle(Palette.muted)
        }
    }
    private func utility(_ id: String,_ title: String,page destination: WorldPage) -> some View {
        Button(title) { page = destination }.font(.caption)
            .frame(maxWidth: .infinity).accessibilityIdentifier("action-\(id)")
    }
    private func activate(_ index: Int) {
        guard actions.indices.contains(index) else { selected = nil; return }
        model.feedbackTap()
        let action = actions[index].0
        if ["FOOD","TRAIN","BATTLE"].contains(action) { model.openCareCommand() }
        switch action {
        case "STATUS": page = .status
        case "FOOD": page = .food
        case "TRAIN": page = .train
        case "BATTLE": model.lastBattle = nil; model.lastQuest = nil; page = .battle
        case "CLEAN": model.care(.clean)
        case "MEDICAL": model.care(.medicine)
        case "SLEEP": page = .sleep
        case "CALL": page = .call
        case "ADVENTURE": page = .adventure
        case "DIGIDEX": page = .digidex
        case "STORAGE": page = .storage
        case "SETTINGS": page = .settings
        default: page = .devices
        }
    }
}

extension WorldViewModel {
    func cancelTrainingIfNeeded(_ page: WorldPage) { if page == .train && state?.training != nil { cancelTraining() } }
}
