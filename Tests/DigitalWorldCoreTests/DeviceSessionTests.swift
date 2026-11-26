import XCTest
@testable import DigitalWorldCore

final class DeviceSessionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_446_400)
    func world() throws -> GameState {
        try DeviceRegistry.newGame(database: .bundled(),deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
    }
    func testSandboxCannotChangeFormalSaveOrCollection() throws {
        let db = try ContentDatabase.bundled(), dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = DeviceLibraryStore(directory: dir,database: db)
        var index = DeviceLibraryIndex(), formal = try world()
        try TimeEngine.advance(&formal,to: now.addingTimeInterval(8),database: db)
        let slot = try library.add(formal,to: &index,at: now)
        let before = try Data(contentsOf: library.store(for: slot).primaryURL)
        var sandbox = formal; sandbox.sessionStyle = .sandbox; sandbox.developerModifiedAt = sandbox.highWatermark
        let testSlot = try library.add(sandbox,to: &index,at: now)
        try DeveloperEngine.perform(.selectSpecies("blitzgreymon"),state: &sandbox,database: db,at: sandbox.highWatermark)
        try library.store(for: testSlot).save(sandbox)
        XCTAssertEqual(try Data(contentsOf: library.store(for: slot).primaryURL),before)
        let entries = CollectionManager.entries(in: [formal,sandbox])
        XCTAssertEqual(entries.map(\.id),["botamon"])
        XCTAssertEqual(entries.first?.obtainedCount,1)
        XCTAssertEqual(try library.loadIndex().slots.count,2)
    }
    func testSandboxVirtualTimePersistsWithoutChangingWallClockOrFormalState() throws {
        let db = try ContentDatabase.bundled(); let formal = try world(); var sandbox = formal
        sandbox.sessionStyle = .sandbox; sandbox.developerModifiedAt = now
        let report = try SandboxEngine.advance(&sandbox,minutes: 11,wallTime: now,database: db)
        XCTAssertEqual(report.hatchings,1); XCTAssertEqual(report.evolutions,1)
        XCTAssertEqual(sandbox.pet.speciesID,"koromon"); XCTAssertEqual(formal.pet.speciesID,"botamon"); XCTAssertTrue(formal.pet.isEgg)
        XCTAssertEqual(SandboxEngine.date(for: sandbox,wallTime: now),now.addingTimeInterval(660))
        let store = SaveStore(directory: URL(fileURLWithPath: "/tmp/unused"),database: db)
        XCTAssertEqual(try store.decode(store.encode(sandbox)).state,sandbox)
        var rejected = formal
        XCTAssertThrowsError(try SandboxEngine.advance(&rejected,minutes: 100,wallTime: now,database: db)); XCTAssertEqual(rejected,formal)
    }
    func testLibraryIndexRecoversBackupAndMissingSlotIsNotReplaced() throws {
        let db = try ContentDatabase.bundled(),dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let library = DeviceLibraryStore(directory: dir,database: db); var index = DeviceLibraryIndex()
        let slot = try library.add(world(),to: &index,at: now); try library.saveIndex(index)
        try Data("damaged".utf8).write(to: dir.appendingPathComponent("devices.json"))
        XCTAssertEqual(try library.loadIndex(),index)
        try FileManager.default.removeItem(at: library.store(for: slot).directory)
        XCTAssertThrowsError(try library.worlds(in: index))
    }
    func testOldV4SaveMigratesAndMissingNewSettingsUseDefaults() throws {
        let db = try ContentDatabase.bundled(),store = SaveStore(directory: URL(fileURLWithPath: "/tmp/unused"),database: db)
        let bytes = try store.encode(world())
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String:Any])
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(base64Encoded: envelope["payload"] as! String)!) as? [String:Any])
        payload["schemaVersion"] = 4; payload.removeValue(forKey: "sessionStyle"); payload.removeValue(forKey: "lifecycles")
        let data = try JSONSerialization.data(withJSONObject: payload,options: [.sortedKeys])
        envelope["payload"] = data.base64EncodedString(); envelope["checksum"] = SaveStore.checksum(data)
        let restored = try store.decode(JSONSerialization.data(withJSONObject: envelope))
        XCTAssertTrue(restored.migrated); XCTAssertEqual(restored.state.schemaVersion,5)
        XCTAssertEqual(restored.state.playStyle,.enhanced); XCTAssertTrue(restored.state.settings.presentation.touchMode)
    }
    func testMoreThan32LifetimesRetainHistoryAndObtains() throws {
        let db = try ContentDatabase.bundled(); var game = try world()
        for _ in 0..<40 {
            game.pets[game.activeIndex].isEgg = false; game.pets[game.activeIndex].speciesID = "agumon"
            game.pets[game.activeIndex].evolutionHistory = ["agumon"]
            game.pets[game.activeIndex].appearances = [SpeciesAppearance("agumon",at: now)]
            game.pets[game.activeIndex].life = .dead; game.pets[game.activeIndex].record("death","回归数据",at: now)
            game.dex["agumon"] = .raised
            try GameEngine.perform(.rebirth("dmc-v1-egg"),state: &game,database: db,at: now)
        }
        XCTAssertEqual(game.lifecycles?.count,40); XCTAssertLessThanOrEqual(game.pets.count,32)
        XCTAssertEqual(CollectionManager.entries(in: [game]).first(where: { $0.id == "agumon" })?.obtainedCount,40)
        try db.validateSave(game)
    }
    func testInputButtonsAndChordsAreDebouncedAndQuestDoesNotExitClassic() throws {
        var router = DeviceInputRouter(), game = try world(), date = now
        func press(_ key: DeviceKey) -> LCDCommand {
            date += 1; _ = router.keyDown(key,at: date); return router.keyUp(key,at: date.addingTimeInterval(0.1),state: game,availableAreas: 1)
        }
        _ = press(.a); XCTAssertEqual(router.selectedIcon,0)
        _ = press(.b); XCTAssertEqual(router.screen,.status)
        _ = press(.b); XCTAssertEqual(router.statusPage,1)
        _ = press(.c); XCTAssertEqual(router.screen,.home)
        _ = router.keyDown(.c,at: date+1); _ = router.keyDown(.a,at: date+1.1)
        XCTAssertEqual(router.screen,.sound)
        XCTAssertEqual(router.keyUp(.a,at: date+1.2,state: game,availableAreas: 1),.none)
        _ = router.keyUp(.c,at: date+1.3,state: game,availableAreas: 1)
        router.screen = .battle; game.sessionStyle = .classic
        XCTAssertEqual(press(.c),.none); XCTAssertEqual(router.screen,.battle)
        game.sessionStyle = .enhanced; XCTAssertEqual(press(.b),.skipBattle)
    }
    func testAmbientMovementTurnsAndAnimationClockUsesMultipleFrames() throws {
        let right = AmbientPetTimeline.sample(seconds: 1),left = AmbientPetTimeline.sample(seconds: 4)
        XCTAssertTrue(right.facesRight); XCTAssertFalse(left.facesRight)
        XCTAssertGreaterThan(right.x,0); XCTAssertLessThan(left.x,64)
        XCTAssertEqual(AmbientPetTimeline.sample(seconds: 7.5).action,"happy")
        XCTAssertGreaterThan(AmbientPetTimeline.sample(seconds: 7.5).yOffset,0)
        for t in stride(from: 0.0,to: 36,by: 0.1) { XCTAssertTrue((-64...64).contains(AmbientPetTimeline.sample(seconds: t).x)) }
        var clock = SpriteAnimationClock(); clock.advance(0.15); clock.advance(0.15)
        XCTAssertEqual(clock.index(count: 2,frameSeconds: 0.28),1)
        clock.advance(0.15); clock.advance(0.15); XCTAssertEqual(clock.index(count: 2,frameSeconds: 0.28),0)
    }
    func testFourLanguagesCoverEveryDeviceLabelAndInvalidPreferencesAreRejected() throws {
        for key in DeviceText.allCases { XCTAssertEqual(DeviceText.words[key]?.count,4) }
        let db = try ContentDatabase.bundled(); var game = try world()
        var ui = game.settings.presentation; ui.brightness = .nan; game.settings.interface = ui
        XCTAssertThrowsError(try db.validateSave(game))
        game = try world(); game.sessionStyle = .sandbox
        XCTAssertThrowsError(try db.validateSave(game))
    }
}
