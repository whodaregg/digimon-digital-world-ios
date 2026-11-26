import SwiftUI
import SpriteKit
import DigitalWorldCore

struct ColorDeviceView: View {
    @ObservedObject var model: WorldViewModel
    @StateObject private var replay = QuestPlaybackController()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let iconIDs = ["STATUS","FOOD","TRAIN","BATTLE","CLEAN","SLEEP","MEDICAL","CALL"]
    private let labels: [DeviceText] = [.status,.food,.training,.quest,.clean,.power,.medical,.call]
    private var ink: Color { Palette.screenInk(model.display) }
    var body: some View {
        VStack(spacing: 8) {
            Text("DIGITAL MONSTER COLOR").font(PixelFont.font(12,language: .english)).foregroundStyle(.black.opacity(0.65))
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    icons(0..<4)
                    HStack {
                        Text(model.state?.pet.isEgg == true ? model.text(.egg) : model.species?.localizedName(model.language) ?? "")
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Spacer(minLength: 2)
                        Text(model.isSandbox ? "TEST" : "Ver.1")
                    }.font(PixelFont.font(10,language: model.language)).padding(.horizontal,6).padding(.top,4)
                    Rectangle().fill(Palette.screenSurface(model.display))
                        .aspectRatio(4/3,contentMode: .fit)
                        .overlay { content.clipped() }
                    icons(4..<8)
                }
                .foregroundStyle(ink)
                .background(Palette.screenSurface(model.display))
                .contrast(model.state?.settings.presentation.contrast ?? 1)
                .brightness((model.state?.settings.presentation.brightness ?? 1)-1)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .padding(5).background(.black.opacity(0.8),in: RoundedRectangle(cornerRadius: 8))
                VStack(spacing: 14) {
                    ForEach(DeviceKey.allCases,id: \.self) { key in
                        DeviceHardwareKey(key: key,model: model).frame(width: 38,height: 34)
                    }
                }.frame(width: 40)
            }
            HStack {
                Circle().fill(.black.opacity(0.5)).frame(width: 5,height: 5)
                Spacer(); Text("A SELECT  B OK  C BACK").font(PixelFont.font(8,language: .english)).foregroundStyle(.black.opacity(0.6)); Spacer()
                Circle().fill(.black.opacity(0.5)).frame(width: 5,height: 5)
            }
        }.padding(14)
            .background(shellColor,in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.black.opacity(0.45),lineWidth: 3))
            .onChange(of: model.lastQuest?.records.first?.id) { _,_ in if model.lastQuest == nil { replay.stop(); model.lcdBattleFinished = false } else { beginReplay() } }
            .onChange(of: model.lcdSkipRequest) { _,_ in replay.skip() }
            .onChange(of: replay.finished) { _,done in model.lcdBattleFinished = done }
            .onAppear { beginReplay() }
            .onDisappear { replay.stop(); model.lcd.cancelTouches() }
    }
    private var shellColor: Color {
        switch model.state?.settings.presentation.shell {
        case "gray": return Color(red: 0.53,green: 0.56,blue: 0.57)
        case "blue": return Color(red: 0.28,green: 0.53,blue: 0.72)
        case "white": return Color(red: 0.81,green: 0.80,blue: 0.73)
        default: return Color(red: 0.64,green: 0.43,blue: 0.29)
        }
    }
    private func icons(_ range: Range<Int>) -> some View {
        HStack(spacing: 2) {
            ForEach(range,id: \.self) { i in
                if i == 7 {
                    TimelineView(.periodic(from: .now,by: 0.5)) { context in
                        PixelGlyph(id: iconIDs[i],color: model.hasCall ? .red : ink.opacity(0.22))
                            .opacity(model.hasCall && !reduceMotion && Int(context.date.timeIntervalSince1970*2)%2 == 0 ? 0.3 : 1)
                            .frame(width: 18,height: 18).frame(maxWidth: .infinity,minHeight: 24)
                            .accessibilityLabel(model.text(.call)).accessibilityValue(model.hasCall ? model.text(.on) : model.text(.off))
                    }
                } else {
                    Button { model.lcdTouch(i) } label: {
                        PixelGlyph(id: iconIDs[i],color: ink).frame(width: 18,height: 18)
                            .frame(maxWidth: .infinity,minHeight: 24)
                            .background(model.lcd.selectedIcon == i ? ink.opacity(0.22) : .clear)
                            .overlay(Rectangle().stroke(model.lcd.selectedIcon == i ? ink : .clear,lineWidth: 1))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(!model.touchEnabled)
                        .accessibilityLabel(model.text(labels[i])).accessibilityIdentifier("action-\(iconIDs[i])")
                }
            }
        }.padding(.horizontal,4)
    }
    @ViewBuilder private var content: some View {
        ZStack {
            switch model.lcd.screen {
            case .home: PetScreen(model: model)
            case .status: status
            case .food: food
            case .training: training
            case .areas: areas
            case .battle: battle
            case .power: menu([model.text(.lights),model.text(.cold),model.text(.backup)])
            case .clock:
                TimelineView(.periodic(from: .now,by: 1)) { _ in
                    VStack(spacing: 12) {
                        Text(model.text(.clock))
                        Text(clockString).font(PixelFont.font(24,language: .english))
                    }.accessibilityIdentifier("lcdClock")
                }
            case .sound: menu([model.text(.sound)+" "+model.text(.on),model.text(.sound)+" "+model.text(.off)])
            case .confirmBackup: confirmation(model.text(.backup))
            case .confirmRebirth: confirmation(model.text(.egg))
            }
            if let notice = model.lcdNotice {
                VStack { Spacer(); Text(notice).font(PixelFont.font(11,language: model.language)).lineLimit(3)
                    .padding(4).frame(maxWidth: .infinity).background(Palette.screenSurface(model.display).opacity(0.95)) }
                    .accessibilityIdentifier("lcdNotice")
            }
        }.font(PixelFont.font(14,language: model.language))
            .accessibilityIdentifier("lcd-\(model.lcd.screen.rawValue)")
    }
    private var clockString: String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; f.timeZone = TimeZone(identifier: model.state?.homeTimeZone ?? "UTC")
        return f.string(from: model.simulationDate)
    }
    @ViewBuilder private var status: some View {
        if let game = model.state {
            let p = game.pet, page = model.lcd.statusPage
            VStack(spacing: 8) {
                Text("\(page+1) / \(model.isClassic ? 6 : 8)").font(PixelFont.font(10,language: .english))
                switch page {
                case 0:
                    readout(.age,"\(p.activeMinutes/1440) "+model.text(.days)); readout(.weight,"\(p.stats.weight)g")
                case 1: hearts(.hunger,p.dmc?.hungerHearts ?? p.stats.fullness/25)
                case 2: hearts(.strength,p.dmc?.strengthHearts ?? p.stats.strength/25)
                case 3: hearts(.effort,p.dmc?.effortHearts ?? 0)
                case 4: readout(.dp,"\(p.stats.dp)")
                case 5: readout(.winRate,"\(Int(p.stats.winRate*100))%")
                case 6: readout(.battleCount,"\(p.stats.battles)"); readout(.wins,"\(p.stats.wins)"); readout(.losses,"\(p.stats.battles-p.stats.wins)")
                default: readout(.species,p.speciesID); readout(.trainingCount,"\(p.stats.trainingAttempts)")
                }
            }.padding(10).accessibilityIdentifier("lcdStatusPage")
        }
    }
    private func readout(_ key: DeviceText,_ value: String) -> some View {
        HStack { Text(model.text(key)); Spacer(minLength: 4); Text(value).lineLimit(1).minimumScaleFactor(0.5) }
    }
    private func hearts(_ title: DeviceText,_ count: Int) -> some View {
        VStack(spacing: 16) {
            Text(model.text(title))
            HStack(spacing: 8) { ForEach(0..<4,id: \.self) { i in
                PixelGlyph(id: i < count ? "heart" : "heartOutline",color: i < count && model.display != .lcd ? .red : ink).frame(width: 22,height: 22)
            } }
        }.accessibilityElement(children: .ignore).accessibilityLabel(model.text(title)).accessibilityValue("\(count) / 4")
    }
    private var food: some View {
        VStack(spacing: 8) {
            PixelGlyph(id: model.lcd.item == 0 ? "meat" : "protein",color: model.lcd.item == 0 && model.display != .lcd ? .brown : ink).frame(width: 42,height: 42)
            Text(model.text(model.lcd.item == 0 ? .meat : .protein))
            if model.touchEnabled {
                HStack {
                    Button("A") { model.lcd.item = (model.lcd.item+1)%2 }
                    Button(model.text(.confirm)) { model.performLCD(.feed(model.lcd.item == 0 ? "meat" : "protein")) }
                        .accessibilityIdentifier("lcdFeed")
                }.buttonStyle(.borderless)
            } else { Text("A SELECT · B FEED").font(PixelFont.font(9,language: .english)) }
        }
        .overlay(alignment: .bottomTrailing) {
            if model.animation == "eat" || model.animation == "refuse" { PetScreen(model: model).frame(width: 95,height: 60).allowsHitTesting(false) }
        }
    }
    private var training: some View {
        VStack(spacing: 4) {
            TrainingPixelScreen(model: model)
            if model.state?.training != nil {
                Text("\(model.state?.dmc?.trainingChoices.count ?? 0) / 5")
                if model.touchEnabled {
                    HStack {
                        Button("A ↑") { model.performLCD(.train("A")) }.accessibilityIdentifier("training-A")
                        Spacer()
                        Button("B ↓") { model.performLCD(.train("B")) }.accessibilityIdentifier("training-B")
                    }.padding(.horizontal,14)
                }
            } else {
                if let score = model.trainingScore { Text("\(score)/5 "+model.text(score >= 3 ? .success : .fail)).accessibilityIdentifier("lcdTrainingResult") }
                Button(model.text(.start)) { model.performLCD(.beginTraining) }.accessibilityIdentifier("beginTraining").disabled(!model.touchEnabled)
            }
        }.font(PixelFont.font(11,language: model.language))
    }
    private var areas: some View {
        VStack(spacing: 12) {
            Text("AREA \(model.lcd.item == 7 ? "F" : String(model.lcd.item+1))").font(PixelFont.font(24,language: .english))
            Text("\((model.database?.dmcV1?.areas[model.lcd.item].opponents.count) ?? 0) BATTLES")
            if model.touchEnabled {
                HStack {
                    Button("◀") { let n = min(8,(model.state?.dmc?.clearedAreas.max() ?? 0)+1); model.lcd.item = (model.lcd.item+1)%max(1,n) }
                    Button(model.text(.start)) { model.performLCD(.quest(model.lcd.item+1)) }.accessibilityIdentifier("lcdQuestStart")
                }
            }
        }
    }
    @ViewBuilder private var battle: some View {
        if let result = model.lastQuest {
            ZStack(alignment: .bottom) {
                SpriteView(scene: replay.scene,preferredFramesPerSecond: 30).accessibilityIdentifier("questArena")
                VStack {
                    HStack { Text("\(replay.battle+1)/\(result.area.opponents.count)").accessibilityIdentifier("questBattleNumber"); Spacer(); Text("\(replay.playerHits) : \(replay.enemyHits)") }
                    Spacer()
                    if replay.finished {
                        Button(model.text(.confirm)) { model.finishLCDQuest() }.accessibilityIdentifier("lcdQuestReturn").disabled(!model.touchEnabled)
                    }
                }.padding(4).font(PixelFont.font(10,language: .english))
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                TimelineView(.periodic(from: .now,by: 0.1)) { _ in
                    Text(replay.scene.diagnostics).font(.system(size: 1)).frame(height: 1).accessibilityIdentifier("questAnimationProbe")
                }
            }
            #endif
        }
    }
    private func menu(_ items: [String]) -> some View {
        VStack(alignment: .leading,spacing: 12) {
            ForEach(items.indices,id: \.self) { i in
                Text((model.lcd.item == i ? "> " : "  ")+items[i]).frame(maxWidth: .infinity,alignment: .leading)
            }
        }.padding(12)
    }
    private func confirmation(_ title: String) -> some View {
        VStack(spacing: 12) { Text(title+"?"); Text((model.lcd.item == 0 ? "> " : "")+model.text(.no)+"   "+(model.lcd.item == 1 ? "> " : "")+model.text(.yes)) }
    }
    private func beginReplay() {
        guard let result = model.lastQuest,model.lcd.screen == .battle else { return }
        replay.stop(); model.lcdBattleFinished = false
        replay.start(result,database: model.database,mode: model.display,reduceMotion: reduceMotion)
    }
}
