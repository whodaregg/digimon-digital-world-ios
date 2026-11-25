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
            if let loaded = try persistence.load() {
                state = loaded.state
                if loaded.recoveredBackup { message = "主存档损坏，已恢复上次备份；损坏文件将保留。" }
                else if loaded.migrated { message = "存档已完成版本升级" }
                else { message = "欢迎回来，伙伴一直在成长" }
                refresh()
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-testing-hatched") {
                var test = try DeviceRegistry.newGame(database: content, deviceID: "ultimate-lab", eggID: "founder",
                                                      now: Date(), timeZone: TimeZone.current.identifier)
                test.pets[0].isEgg = false; test.pets[0].speciesID = "agumon"
                test.pets[0].evolutionHistory = ["botamon", "koromon", "agumon"]
                test.dex["agumon"] = .raised
                test.inventory["fruit"] = 2
                state = test
            }
            #endif
        } catch {
            database = nil
            fatalError = error.localizedDescription
        }
    }

    var species: Species? { state.flatMap { try? database?.species($0.pet.speciesID) } }
    var exportURL: URL? { store?.primaryURL }
    var display: DisplayMode { state?.settings.display ?? .lcd }
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
            state = try DeviceRegistry.newGame(database: database, deviceID: "ultimate-lab", eggID: eggID,
                                               now: Date(), timeZone: TimeZone.current.identifier)
            message = "孵化已开始 · 5 分钟后诞生"
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
