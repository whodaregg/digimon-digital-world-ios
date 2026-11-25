import SwiftUI
import DigitalWorldCore

@MainActor
final class WorldViewModel: ObservableObject {
    @Published private(set) var state: GameState?
    @Published var message = "欢迎来到数码世界"
    @Published var alert: String?
    @Published var fatalError: String?
    @Published var animation = "idle"
    @Published var lastBattle: BattleRecord?
    @Published var encounter: String?
    @Published var trainingScore: Int?
    @Published var lastQuest: DMCQuestResult?
    @Published private(set) var previousProfileBackupURL: URL?
    private(set) var database: ContentDatabase?
    private var store: SaveStore?
    private var lastPersist = Date.distantPast
    private var feedback = FeedbackEngine()
    private let notifications = NotificationCoordinator()
    private var animationTask: Task<Void, Never>?

    init() {
        do {
            let content = try ContentDatabase.bundled()
            database = content
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            var directory = base.appendingPathComponent("DigitalWorld", isDirectory: true)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                directory = base.appendingPathComponent("DigitalWorld-UITests", isDirectory: true)
                try? FileManager.default.removeItem(at: directory)
            }
            #endif
            let persistence = SaveStore(directory: directory, database: content)
            store = persistence
            previousProfileBackupURL = (try? FileManager.default.contentsOfDirectory(at: directory,includingPropertiesForKeys: [.contentModificationDateKey]))?
                .filter { $0.lastPathComponent.hasPrefix("world.before-restore.") && $0.pathExtension == "json" }
                .max { a,b in
                    let left = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    let right = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                    return left < right
                }
            if let loaded = try persistence.load() {
                state = loaded.state
                if loaded.recoveredBackup { message = "主存档损坏，已恢复上次备份；损坏文件将保留。" }
                else if loaded.migrated { message = "存档已完成版本升级" }
                else { message = "欢迎回来，伙伴一直在成长" }
                refresh()
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-hatched") || ProcessInfo.processInfo.arguments.contains("--ui-testing-legacy") {
                let legacy = ProcessInfo.processInfo.arguments.contains("--ui-testing-legacy")
                var test = try DeviceRegistry.newGame(database: content, deviceID: legacy ? "ultimate-lab" : "dmc-ver1", eggID: legacy ? "founder" : "dmc-v1-egg",
                                                      now: Date(), timeZone: TimeZone.current.identifier)
                test.pets[0].isEgg = false; test.pets[0].speciesID = "agumon"
                test.pets[0].evolutionHistory = ["botamon", "koromon", "agumon"]
                test.dex["agumon"] = .raised
                test.pets[0].stats.weight = 20; test.pets[0].stats.dp = 20
                if !legacy {
                    test.pets[0].dmc!.hungerHearts = 3; test.pets[0].dmc!.strengthHearts = 4
                    test.pets[0].stats.fullness = 75; test.pets[0].stats.strength = 100
                    // Keep the original fixture awake regardless of CI wall-clock hour.
                    test.pets[0].dmc!.awakeUntil = Date().addingTimeInterval(3600)
                }
                test.homeTimeZone = "UTC"
                state = test
            }
            #endif
        } catch {
            fatalError = error.localizedDescription
        }
    }

    var species: Species? { state.flatMap { try? database?.species($0.pet.speciesID) } }
    var exportURL: URL? { store?.primaryURL }
    var display: DisplayMode { state?.settings.display ?? .color }
    var isOriginal: Bool { state?.deviceID == DMCV1Engine.deviceID }
    var hatchRemainingSeconds: Int {
        guard let care = state?.pet.dmc else { return 0 }
        return max(0,Int(ceil(care.eggStartedAt.addingTimeInterval(8).timeIntervalSinceNow)))
    }
    var callMessage: String {
        guard let p = state?.pet, let c = p.dmc else { return "没有呼叫" }
        var calls: [String] = []
        if c.hungerCall != nil { calls.append("空腹：请喂肉") }
        if c.strengthCall != nil { calls.append("力量不足：请训练或喂蛋白质") }
        if c.sleepCall != nil { calls.append("正在睡觉：请关灯") }
        if p.stats.injured { calls.append("受伤：请治疗") }
        return calls.isEmpty ? "目前没有养成呼叫" : calls.joined(separator: "\n")
    }
    var hasCall: Bool {
        guard let p = state?.pet, let c = p.dmc else { return false }
        return c.hungerCall != nil || c.strengthCall != nil || c.sleepCall != nil
    }
    var hatchRemainingMinutes: Int {
        guard let game = state, let egg = try? database?.egg(game.pet.eggID) else { return 0 }
        return max(0,egg.hatchMinutes-game.pet.stageMinutes)
    }
    var animationName: String {
        guard let p = state?.pet else { return "idle" }
        if p.life == .dead { return "defeat" }
        if p.sleeping { return "sleep" }
        if p.stats.injured { return "injured" }
        if animation != "idle" { return animation }
        if p.stats.fullness < 20 { return "hungry" }
        if p.stats.sick { return "sad" }
        return "idle"
    }
    func start(eggID: String) {
        guard let database, fatalError == nil else { return }
        do {
            state = try DeviceRegistry.newGame(database: database, deviceID: "dmc-ver1", eggID: "dmc-v1-egg",
                                               now: Date(), timeZone: TimeZone.current.identifier)
            message = "Ver.1 孵化已开始 · 8 秒后诞生"
            persist(); play("evolution")
        } catch { alert = error.localizedDescription }
    }
    func refresh(now: Date = Date(), forceSave: Bool = false) {
        guard var game = state, let database, fatalError == nil else { return }
        do {
            let result = try TimeEngine.advance(&game, to: now, database: database)
            state = game
            if result.clockReversed { message = "检测到设备时间倒退，请恢复正确时间" }
            else if result.deaths > 0 { message = "伙伴回归数据，记录已保留"; play("defeat") }
            else if result.evolutions > 0 { message = "伙伴进化了！"; play("evolution") }
            else if result.hatchings > 0 { message = "新生命诞生，开始照顾它吧"; play("happy") }
            if forceSave || now.timeIntervalSince(lastPersist) >= 60 { persist() }
        } catch { alert = error.localizedDescription }
    }
    func care(_ action: CareAction) {
        command { game, content, now in try GameEngine.perform(action, state: &game, database: content, at: now) }
        guard alert == nil else { return }
        switch action {
        case .feed: message = "喂食完成"; play("eat")
        case .clean: message = "环境清理完成"; play("happy")
        case .medicine: message = "治疗完成"; play("happy")
        case .lights(let off): message = off ? "灯光已关闭" : "灯光已开启"
        case .rest(let rest): message = rest ? "休息中，恢复能量" : "已结束手动休息；作息时间内仍会睡眠"
        case .freeze(let frozen): message = frozen ? "成长已暂停" : "成长已恢复"
        case .rebirth: message = "新数码蛋开始孵化"; play("evolution")
        case .selectPet: message = "已切换查看的伙伴"
        }
    }
    func beginTraining() {
        trainingScore = nil
        command { game, _, now in try TrainingEngine.begin(&game, at: now) }
    }
    func originalTraining(_ choice: String) {
        command { game, content, now in
            trainingScore = try DMCV1Engine.train(&game,choice: choice,database: content,at: now)
        }
        play(trainingScore.map { $0 >= 3 ? "victory" : "sad" } ?? "attack")
    }
    func openCareCommand() {
        guard isOriginal, state?.pet.isEgg == false, state?.pet.life == .alive else { return }
        command { game, _, now in try DMCV1Engine.wake(&game,at: now) }
    }
    func quest(_ area: Int) {
        lastQuest = nil
        command { game, content, now in
            lastQuest = try DMCV1Engine.quest(&game,areaID: area,database: content,at: now)
        }
        if let result = lastQuest {
            message = result.cleared ? "\(result.area.name) 通关" : "挑战结束，下次从本区首战重新开始"
            play(result.cleared ? "victory" : "hit")
        }
    }
    func swapBackup() {
        command { game, _, now in try DMCV1Engine.swapBackup(&game,at: now) }
    }
    func selectBackground(_ id: String) {
        command { game, _, _ in
            guard game.dmc?.backgrounds.contains(id) == true else { throw GameError.cannotAct("背景尚未解锁") }
            game.dmc!.selectedBackground = id
        }
    }
    func startOriginalProfile() {
        guard let database, let current = state, !isOriginal else { return }
        do {
            var candidate = try DeviceRegistry.newGame(database: database,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: Date(),timeZone: TimeZone.current.identifier)
            candidate.settings = current.settings
            restoreBackup(candidate)
            message = "旧档已独立备份，开始 Ver.1 养成"
        } catch { alert = error.localizedDescription }
    }
    func restorePreviousProfile() {
        guard let url = previousProfileBackupURL else { return }
        do { restoreBackup(try inspectBackup(url)) }
        catch { alert = "旧档校验失败：\(error.localizedDescription)" }
    }
    func tapTraining() {
        command { game, _, now in
            guard let id = game.training?.id else { throw GameError.cannotAct("请先开始训练") }
            trainingScore = try TrainingEngine.tap(&game, sessionID: id, at: now)
        }
        if let trainingScore { play(trainingScore >= 60 ? "victory" : "sad") }
        else { play("training") }
    }
    func cancelTraining() {
        command { game, _, _ in game.training = nil }
    }
    func fight(_ opponent: String) {
        command { game, content, now in
            lastBattle = try BattleEngine.fight(&game, opponentID: opponent, database: content, at: now)
        }
        if let lastBattle { message = lastBattle.won ? "对战胜利 · 恢复食物 +1" : "伙伴受伤，请先治疗"; play(lastBattle.won ? "victory" : "hit") }
    }
    func move(dx: Int, dy: Int) {
        command { game, content, now in
            let result = try AdventureEngine.move(&game, dx: dx, dy: dy, database: content, at: now)
            message = result.message; encounter = result.encounter
        }
    }
    func settings(_ change: (inout Settings) -> Void) {
        guard var game = state else { return }
        change(&game.settings); state = game; persist()
    }
    func setNotifications(_ enabled: Bool) {
        if !enabled {
            settings { $0.notifications = false }; notifications.cancel(); return
        }
        Task {
            do {
                let granted = try await notifications.requestAuthorization()
                settings { $0.notifications = granted }
                if granted { scheduleNotifications() }
                else { alert = "通知权限未开启，可在 iOS 设置中修改。养成功能仍可离线使用。" }
            } catch { alert = error.localizedDescription }
        }
    }
    func persist() {
        guard let game = state, let store, fatalError == nil else { return }
        do { try store.save(game); lastPersist = Date() }
        catch { alert = "存档写入失败：\(error.localizedDescription)" }
    }
    func scheduleNotifications() {
        guard let game = state, let database else { return }
        notifications.schedule(game: game, database: database)
    }
    func feedbackTap() { feedback.play(sound: state?.settings.sound ?? true, haptics: state?.settings.haptics ?? true) }
    func inspectBackup(_ url: URL) throws -> GameState {
        guard let store else { throw GameError.invalidData("内容数据库不可用，无法验证备份") }
        let granted = url.startAccessingSecurityScopedResource()
        defer { if granted { url.stopAccessingSecurityScopedResource() } }
        return try store.decode(Data(contentsOf: url)).state
    }
    func restoreBackup(_ candidate: GameState) {
        guard let store else { return }
        do {
            if let current = state {
                // Keep a separate copy so autosave rotation cannot erase the pre-import world.
                let preserved = store.directory.appendingPathComponent("world.before-restore.\(UUID().uuidString).json")
                try FileManager.default.createDirectory(at: store.directory,withIntermediateDirectories: true)
                try store.encode(current).write(to: preserved,options: .atomic)
                previousProfileBackupURL = preserved
            }
            try store.save(candidate)
            state = candidate; fatalError = nil; message = "备份已恢复，正在结算离线时间"
            refresh(forceSave: true)
        } catch { alert = "恢复失败：\(error.localizedDescription)" }
    }
    private func command(_ operation: (inout GameState, ContentDatabase, Date) throws -> Void) {
        alert = nil
        guard var game = state, let database, fatalError == nil else { return }
        let now = Date()
        do {
            try TimeEngine.advance(&game, to: now, database: database)
            guard now >= game.highWatermark else { throw GameError.cannotAct("设备时间早于存档时间，请恢复正确时间") }
            try operation(&game, database, now)
            state = game; persist(); feedbackTap()
        } catch {
            // Time still passes when an action is refused.
            state = game; persist(); alert = error.localizedDescription
        }
    }
    private func play(_ value: String) {
        animationTask?.cancel(); animation = value
        animationTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(value == "evolution" ? 3 : 1.6))
            guard !Task.isCancelled else { return }
            self?.animation = "idle"
        }
    }
}
