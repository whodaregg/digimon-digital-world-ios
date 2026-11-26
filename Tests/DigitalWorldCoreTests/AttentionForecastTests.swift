import XCTest
@testable import DigitalWorldCore

final class AttentionForecastTests: XCTestCase {
    func testHatchAndCareForecastDoesNotMutateActualSave() throws {
        let db = try ContentDatabase.bundled(), now = Date(timeIntervalSince1970: 1_800_446_400)
        let game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        let events = try AttentionForecast.reminders(for: game,database: db,from: now)
        XCTAssertEqual(events.first?.kind,"hatch"); XCTAssertEqual(events.first?.date,now.addingTimeInterval(8))
        XCTAssertTrue(events.contains { $0.kind == "hunger" }); XCTAssertTrue(game.pet.isEgg)
        XCTAssertEqual(game.highWatermark,now); XCTAssertEqual(game.pet.history.count,1)
    }
    func testSandboxAndColdDoNotScheduleFormalReminders() throws {
        let db = try ContentDatabase.bundled(), now = Date(timeIntervalSince1970: 1_800_446_400)
        var game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        game.sessionStyle = .sandbox; game.developerModifiedAt = now
        XCTAssertTrue(try AttentionForecast.reminders(for: game,database: db,from: now).isEmpty)
        game.sessionStyle = .enhanced; game.pets[0].life = .frozen
        XCTAssertTrue(try AttentionForecast.reminders(for: game,database: db,from: now).isEmpty)
    }
}

final class MotionAndArchiveTests: XCTestCase {
    func testMotionCounterRejectsGravityNoiseAndHeldPeaks() {
        var counter = MotionInputCounter()
        XCTAssertFalse(counter.sample(x: 0,y: 0,z: 1,time: 1))
        XCTAssertTrue(counter.sample(x: 2,y: 0,z: 1,time: 2))
        XCTAssertFalse(counter.sample(x: 2,y: 0,z: 1,time: 3))
        XCTAssertFalse(counter.sample(x: 0,y: 0,z: 1,time: 3.1))
        XCTAssertTrue(counter.sample(x: -2,y: 0,z: 1,time: 3.4))
        XCTAssertEqual(counter.count,2)
        XCTAssertFalse(counter.sample(x: .nan,y: 0,z: 0,time: 4))
    }
    func testResetArchivesLivingPetWithoutClaimingADeath() throws {
        let db = try ContentDatabase.bundled(),now = Date(timeIntervalSince1970: 1_800_446_400)
        var game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        try TimeEngine.advance(&game,to: now.addingTimeInterval(8),database: db)
        LifecycleManager.archiveBeforeReset(&game,at: game.highWatermark)
        XCTAssertEqual(game.lifecycles?.first?.reason,"reset")
        XCTAssertEqual(game.pet.life,.alive)
        XCTAssertEqual(CollectionManager.entries(in: [game]).first?.obtainedCount,1)
    }
}

final class SaveBoundaryAndHardwareTests: XCTestCase {
    func testOversizeWriteCannotReplaceAReadableSave() throws {
        let db = try ContentDatabase.bundled(),now = Date(timeIntervalSince1970: 1_800_446_400)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir,database: db)
        var game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        try store.save(game); let before = try Data(contentsOf: store.primaryURL)
        game.pets[0].record("test",String(repeating: "x",count: 13_000_000),at: now)
        XCTAssertThrowsError(try store.save(game))
        XCTAssertEqual(try Data(contentsOf: store.primaryURL),before)
        XCTAssertTrue(try XCTUnwrap(store.load()).state.pet.isEgg)
    }
    func testOriginalLongCAndDeathABChordExecuteRealRebirth() throws {
        let db = try ContentDatabase.bundled(),now = Date(timeIntervalSince1970: 1_800_446_400)
        var game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now),router = DeviceInputRouter()
        game.sessionStyle = .classic
        _ = router.keyDown(.c,at: now,state: game)
        _ = router.keyUp(.c,at: now.addingTimeInterval(2.1),state: game,availableAreas: 1)
        XCTAssertEqual(router.screen,.deviceSettings)
        router.returnHome()
        try TimeEngine.advance(&game,to: now.addingTimeInterval(8),database: db)
        game.pets[0].life = .dead; game.pets[0].record("death","测试死亡状态",at: game.highWatermark)
        let id = game.pet.id
        _ = router.keyDown(.a,at: game.highWatermark,state: game)
        XCTAssertEqual(router.keyDown(.b,at: game.highWatermark.addingTimeInterval(0.1),state: game),.rebirth)
        try GameEngine.perform(.rebirth("dmc-v1-egg"),state: &game,database: db,at: game.highWatermark)
        XCTAssertTrue(game.pet.isEgg); XCTAssertNotEqual(game.pet.id,id)
        XCTAssertEqual(game.dex["botamon"],.raised); XCTAssertEqual(game.lifecycles?.first?.id,id)
    }
}
