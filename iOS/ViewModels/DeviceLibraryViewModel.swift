import Foundation
import DigitalWorldCore

extension WorldViewModel {
    var activeSlot: DeviceSlot? { libraryIndex.slots.first { $0.id == libraryIndex.activeID } }
    var formalSlots: [DeviceSlot] { libraryIndex.slots.filter { $0.style.isFormal } }
    var isSandbox: Bool { state?.playStyle == .sandbox }
    var isClassic: Bool { state?.playStyle == .classic }
    var touchEnabled: Bool { !isClassic && (state?.settings.presentation.touchMode ?? true) }
    func editPresentation(_ change: (inout DevicePresentationSettings) -> Void) {
        settings { settings in var ui = settings.presentation; change(&ui); settings.interface = ui }
    }
    func setPlayStyle(_ style: PlayStyle) {
        if style == .sandbox { enterSandbox(); return }
        if isSandbox {
            if let formal = formalSlots.first(where: { $0.deviceID == state?.deviceID }) { activateSlot(formal.id) }
            else { createDevice(state?.deviceID ?? DMCV1Engine.deviceID,style: style) }
            guard !isSandbox else { return }
        }
        guard var game = state else { return }
        game.sessionStyle = style
        do { try commit(game); updateLibraryMetadata() } catch { alert = error.localizedDescription }
    }
    func createDevice(_ deviceID: String,style: PlayStyle = .enhanced) {
        guard let database,let library else { return }
        do {
            let device = try database.device(deviceID)
            guard device.enabled,device.verifiedOriginal || style == .sandbox else { throw GameError.unavailable("该型号的规则或原版素材尚待核验，暂不能创建养成档案") }
            guard let egg = device.eggs.first else { throw GameError.invalidData("该设备没有可用数码蛋") }
            var game = try DeviceRegistry.newGame(database: database,deviceID: deviceID,eggID: egg,now: Date(),timeZone: TimeZone.current.identifier)
            game.sessionStyle = style; game.settings = state?.settings ?? Settings()
            if style == .sandbox { game.developerModifiedAt = game.highWatermark }
            try saveCurrentSlot()
            let slot = try library.add(game,to: &libraryIndex,at: Date())
            install(game,slot: slot); message = "已创建独立设备档案"
        } catch { alert = error.localizedDescription }
    }
    func activateSlot(_ id: UUID) {
        guard id != libraryIndex.activeID,let library,let database,let slot = libraryIndex.slots.first(where: { $0.id == id }) else { return }
        do {
            try saveCurrentSlot()
            let target = library.store(for: slot)
            guard var game = try target.load()?.state else { throw GameError.invalidData("该设备档案缺失，其他存档保持原样") }
            guard game.deviceID == slot.deviceID,game.playStyle.isFormal == slot.style.isFormal else { throw GameError.invalidData("设备档案与索引不一致") }
            try TimeEngine.advance(&game,to: SandboxEngine.date(for: game,wallTime: Date()),database: database); try target.save(game)
            var index = libraryIndex; index.activeID = id
            if let i = index.slots.firstIndex(where: { $0.id == id }) { index.slots[i].lastOpenedAt = Date(); index.slots[i].style = game.playStyle }
            try library.saveIndex(index); libraryIndex = index
            install(game,slot: slot); message = "设备已切换，已结算该设备离线时间"
        } catch { alert = error.localizedDescription }
    }
    func enterSandbox() {
        guard !isSandbox,let current = state,let library else { return }
        if let existing = libraryIndex.slots.first(where: { $0.deviceID == current.deviceID && !$0.style.isFormal }) {
            activateSlot(existing.id); return
        }
        do {
            try saveCurrentSlot()
            var copy = current; copy.sessionStyle = .sandbox
            copy.developerModifiedAt = copy.highWatermark; copy.training = nil
            let slot = try library.add(copy,to: &libraryIndex,at: Date())
            install(copy,slot: slot); message = "已进入独立Sandbox，正式养成和收藏保持隔离"
        } catch { alert = error.localizedDescription }
    }
    func advanceSandbox(minutes: Int) {
        guard isSandbox,(1...43_200).contains(minutes),var game = state,let database else { return }
        do {
            try SandboxEngine.advance(&game,minutes: minutes,wallTime: Date(),database: database)
            try commit(game); lastQuest = nil; lastBattle = nil
            message = "Sandbox已推进\(minutes)分钟"; refreshCollection()
        } catch { alert = error.localizedDescription }
    }
    func resetCurrentDevice() {
        guard let old = state,let database,let store else { return }
        do {
            let device = try database.device(old.deviceID)
            guard let egg = device.eggs.first else { return }
            let now = max(simulationDate,old.highWatermark)
            var archived = old; LifecycleManager.archiveBeforeReset(&archived,at: now)
            var game = try DeviceRegistry.newGame(database: database,deviceID: old.deviceID,eggID: egg,now: now,timeZone: old.homeTimeZone)
            game.settings = old.settings; game.sessionStyle = old.playStyle; game.sandboxOffsetSeconds = old.sandboxOffsetSeconds
            game.dex = old.dex; game.lifecycles = archived.lifecycles
            if old.playStyle == .sandbox { game.developerModifiedAt = game.highWatermark }
            let path = store.directory.appendingPathComponent("world.before-reset.\(UUID().uuidString).json")
            try store.encode(old).write(to: path,options: .atomic)
            try store.save(game); state = game; lastQuest = nil; lastBattle = nil; trainingScore = nil
            message = "设备已重置，重置前档案已单独保留"; refreshCollection()
        } catch { alert = error.localizedDescription }
    }
    func refreshCollection() {
        guard let library else { return }
        var worlds: [GameState] = []
        for slot in libraryIndex.slots where slot.style.isFormal {
            if slot.id == libraryIndex.activeID,let current = state { worlds.append(current) }
            else if let world = try? library.store(for: slot).load()?.state { worlds.append(world) }
        }
        collectionEntries = CollectionManager.entries(in: worlds)
    }
    func updateLibraryMetadata() {
        guard let library,let activeID = libraryIndex.activeID,let game = state,
              let i = libraryIndex.slots.firstIndex(where: { $0.id == activeID }) else { return }
        libraryIndex.slots[i].style = game.playStyle
        do { try library.saveIndex(libraryIndex) } catch { alert = error.localizedDescription }
    }
    func saveCurrentSlot() throws { if let state,let store { try store.save(state) } }
    func install(_ game: GameState,slot: DeviceSlot) {
        state = game; store = library?.store(for: slot); fatalError = nil; lcd.returnHome(); lcdNotice = nil
        lastQuest = nil; lastBattle = nil; trainingScore = nil; animation = "idle"
        lockDeveloper(); developerBackupURL = nil
        refreshCollection(); updateLibraryMetadata()
    }
}
