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
