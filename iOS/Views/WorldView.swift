import SwiftUI
import DigitalWorldCore

enum WorldPage: String, Identifiable, CaseIterable {
    case status, food, train, battle, sleep, adventure, digidex, storage, settings, devices
    var id: String { rawValue }
    var title: String {
        switch self {
        case .status: return "伙伴状态"
        case .food: return "喂食"
        case .train: return "精准训练"
        case .battle: return "离线对战"
        case .sleep: return "睡眠与休息"
        case .adventure: return "数码世界"
        case .digidex: return "DIGIDEX"
        case .storage: return "伙伴档案"
        case .settings: return "设置"
        case .devices: return "DIGIVICE SELECT"
        }
    }
}

struct WorldView: View {
    @ObservedObject var model: WorldViewModel
    @State private var page: WorldPage?
    @State private var selected = 0
    @Environment(\.scenePhase) private var phase
    private let timer = Timer.publish(every: 15,on: .main,in: .common).autoconnect()
    private let actions: [(String,String,String)] = [
        ("STATUS","状态","chart.bar.xaxis"), ("FOOD","喂食","fork.knife"),
        ("TRAIN","训练","scope"), ("BATTLE","对战","bolt.shield"),
        ("CLEAN","清洁","sparkles"), ("MEDICAL","医疗","cross.case"),
        ("SLEEP","睡眠","moon.zzz"), ("ADVENTURE","冒险","map"),
        ("DIGIDEX","图鉴","square.grid.2x2"), ("STORAGE","档案","archivebox"),
        ("SETTINGS","设置","slider.horizontal.3"), ("DIGIVICE","机型","gamecontroller")
    ]
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
                }.padding(28)
            } else if model.state != nil {
                home
            } else if model.database != nil {
                welcome
            }
        }
        .onReceive(timer) { _ in if phase == .active { model.refresh() } }
        .sheet(item: $page) { value in
            NavigationStack {
                DetailView(page: value,model: model)
                    .background(Palette.background)
                    .navigationTitle(value.title).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) { Button("完成") { model.cancelTrainingIfNeeded(value); page = nil } }
                    }
            }.presentationDragIndicator(.visible)
                .onDisappear { if model.state?.training != nil { model.cancelTraining() } }
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
                            Text("5 分钟孵化 · 幼年期 I").font(.caption).foregroundStyle(Palette.muted)
                            Text("1997 LAB / ULTIMATE").font(.system(.caption2,design: .monospaced)).foregroundStyle(Palette.amber)
                        }
                    }
                    Text("从一枚蛋开始。喂食、清洁、互动训练，让你的照顾方式决定它的成长。离开后时间仍然流逝。")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    GameButton(title: "孵化这枚数码蛋") { model.start(eggID: "founder") }
                        .accessibilityIdentifier("startHatching")
                }
                Panel(title: "当前内容 / 开发中") {
                    Text("本版本使用原创融合规则与原创测试像素素材。角色资料分字段标注核验状态；Original Mode 须完成实体说明书核验后开放。")
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
                    HStack(spacing: 18) {
                        Metric(name: "饱食 FULL",value: state.pet.stats.fullness)
                        Metric(name: "能量 ENERGY",value: state.pet.stats.energy,color: Palette.amber)
                        Metric(name: "健康 HEALTH",value: state.pet.stats.health)
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
                                    .foregroundStyle(selected == index ? Palette.mint : Palette.muted)
                                    .background(selected == index ? Palette.mint.opacity(0.08) : Palette.panel,in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected == index ? Palette.mint.opacity(0.65) : Palette.line,lineWidth: 1))
                            }.buttonStyle(.plain).accessibilityLabel(actions[index].1).accessibilityIdentifier("action-\(actions[index].0)")
                        }
                    }
                    hardwareButtons
                    HStack {
                        Text("LOCAL SAVE / AUTO").font(.system(size: 9,design: .monospaced))
                        Spacer()
                        Text("v0.1.0 · ULTIMATE LAB").font(.system(size: 9,design: .monospaced))
                    }.foregroundStyle(Palette.muted.opacity(0.7))
                }
            }.pageStyle()
        }.accessibilityIdentifier("worldHome")
    }
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading,spacing: 3) {
                Text("DIGIMON").font(.system(size: 23,weight: .black,design: .monospaced)).tracking(3).foregroundStyle(Palette.mint)
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
                Text("1997 LAB").font(.system(size: 10,weight: .black,design: .monospaced)).foregroundStyle(Palette.amber)
                Spacer()
                Text(state.pet.life == .frozen ? "❄ PAUSED" : state.pet.life == .dead ? "MEMORY" : state.pet.sleeping ? "SLEEPING" : "● LIVE")
                    .font(.system(size: 9,weight: .bold,design: .monospaced)).foregroundStyle(Palette.mint)
            }
            VStack(spacing: 0) {
                HStack {
                    Text(state.pet.isEgg ? "DIGI-EGG" : model.species?.name.uppercased() ?? "UNKNOWN")
                    Spacer()
                    Text(state.pet.isEgg ? "HATCHING" : "\(state.pet.activeMinutes / 1440) D · \(model.species?.stage.rawValue.uppercased() ?? "")")
                }.font(.system(size: 9,weight: .bold,design: .monospaced)).foregroundStyle(Color(red: 0.2,green: 0.28,blue: 0.2))
                    .padding(.horizontal,12).padding(.top,10).background(Color(red: 0.66,green: 0.73,blue: 0.52))
                PetScreen(model: model)
                HStack {
                    Text(state.pet.isEgg ? "破壳倒计时 \(max(0,5-state.pet.stageMinutes)) MIN" : "\(state.pet.stats.weight) g  ·  \(state.pet.personality.uppercased())")
                    Spacer()
                    Text("DP \(state.pet.stats.dp)")
                }.font(.system(size: 8,weight: .bold,design: .monospaced)).foregroundStyle(Color(red: 0.2,green: 0.28,blue: 0.2))
                    .padding(10).background(Color(red: 0.66,green: 0.73,blue: 0.52))
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
            hardware("A","选择") { selected = (selected+1)%actions.count; model.feedbackTap() }
            hardware("B","确认") { activate(selected) }
            hardware("C","返回") { if page != nil { page = nil } else { selected = 0 }; model.feedbackTap() }
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
    private func activate(_ index: Int) {
        model.feedbackTap()
        switch index {
        case 0: page = .status
        case 1: page = .food
        case 2: page = .train
        case 3: model.lastBattle = nil; page = .battle
        case 4: model.care(.clean)
        case 5: model.care(.medicine)
        case 6: page = .sleep
        case 7: page = .adventure
        case 8: page = .digidex
        case 9: page = .storage
        case 10: page = .settings
        default: page = .devices
        }
    }
}

extension WorldViewModel {
    func cancelTrainingIfNeeded(_ page: WorldPage) { if page == .train && state?.training != nil { cancelTraining() } }
}
