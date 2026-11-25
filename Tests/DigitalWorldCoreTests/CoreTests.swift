import XCTest
@testable import DigitalWorldCore

final class CoreTests: XCTestCase {
    // UTC midday. Tests inject time; they never sleep or depend on the machine clock.
    let noon = Date(timeIntervalSince1970: 1_800_446_400)
    func db() throws -> ContentDatabase { try .bundled() }
    func game() throws -> GameState {
        try DeviceRegistry.newGame(database: db(), deviceID: "ultimate-lab", eggID: "founder", now: noon)
    }
    func hatched(_ species: String = "botamon") throws -> GameState {
        var g = try game()
        g.pets[0].isEgg = false; g.pets[0].speciesID = species
        g.pets[0].evolutionHistory = [species]; g.dex[species] = .raised
        return g
    }
    func testDatabaseReferencesAndStudySheets() throws {
        let content = try db()
        try content.validate()
        XCTAssertEqual(content.species.count, 8)
        let manifest = try SpriteLibrary.manifest()
        XCTAssertEqual(manifest.animations.count, 15)
        for s in content.species {
            let data = try SpriteLibrary.imageData(id: s.spriteID)
            XCTAssertEqual(Array(data.prefix(8)), [137,80,78,71,13,10,26,10])
            XCTAssertEqual(s.balanceProvenance.prefix(16), "original-balance")
        }
    }
    func testOriginalModeCannotMasqueradeAsVerified() throws {
        XCTAssertThrowsError(try DeviceRegistry.newGame(database: db(), deviceID: "dm1", eggID: "founder", now: noon))
        var content = try db(); content.devices[1].enabled = true
        XCTAssertThrowsError(try content.validate())
    }
    func testEggDoesNotHatchEarly() throws {
        var state = try game()
        try TimeEngine.advance(&state, to: noon.addingTimeInterval(299), database: db())
        XCTAssertTrue(state.pet.isEgg)
        let report = try TimeEngine.advance(&state, to: noon.addingTimeInterval(300), database: db())
        XCTAssertFalse(state.pet.isEgg); XCTAssertEqual(report.hatchings, 1)
        XCTAssertEqual(state.pet.speciesID, "botamon"); XCTAssertEqual(state.dex["botamon"], .raised)
    }
    func testLockedEggCannotStartGame() throws {
        XCTAssertThrowsError(try DeviceRegistry.newGame(database: db(), deviceID: "ultimate-lab", eggID: "signal", now: noon))
    }
    func testOfflineAndFrequentReopensAreIdentical() throws {
        let content = try db()
        var offline = try game(); var online = offline
        let end = noon.addingTimeInterval(10 * 3600 + 37)
        try TimeEngine.advance(&offline, to: end, database: content)
        for seconds in stride(from: 7, through: 10 * 3600 + 37, by: 7) {
            try TimeEngine.advance(&online, to: noon.addingTimeInterval(Double(seconds)), database: content)
        }
        try TimeEngine.advance(&online, to: end, database: content)
        XCTAssertEqual(offline, online)
    }
    func testDuplicateAndFractionalMinutes() throws {
        var state = try hatched()
        for seconds in [10,20,30,40,50,59] {
            try TimeEngine.advance(&state, to: noon.addingTimeInterval(Double(seconds)), database: db())
        }
        XCTAssertEqual(state.pet.activeMinutes, 0)
        try TimeEngine.advance(&state, to: noon.addingTimeInterval(61), database: db())
        XCTAssertEqual(state.pet.activeMinutes, 1)
        let snapshot = state
        try TimeEngine.advance(&state, to: noon.addingTimeInterval(61), database: db())
        XCTAssertEqual(snapshot, state)
    }
    func testClockRollbackDoesNotGrantTimeOrActions() throws {
        var state = try hatched()
        try TimeEngine.advance(&state, to: noon.addingTimeInterval(3600), database: db())
        let snapshot = state
        let report = try TimeEngine.advance(&state, to: noon, database: db())
        XCTAssertTrue(report.clockReversed); XCTAssertEqual(state, snapshot)
        XCTAssertThrowsError(try GameEngine.perform(.feed("meat"), state: &state, database: db(), at: noon))
        XCTAssertEqual(state, snapshot)
    }
    func testFrozenPetDoesNotAgeAndDoesNotCatchUpAfterThaw() throws {
        var state = try hatched()
        try GameEngine.perform(.freeze(true), state: &state, database: db(), at: noon)
        let later = noon.addingTimeInterval(20 * 86400)
        try TimeEngine.advance(&state, to: later, database: db())
        XCTAssertEqual(state.pet.activeMinutes, 0); XCTAssertEqual(state.pet.stats.fullness, 80)
        try GameEngine.perform(.freeze(false), state: &state, database: db(), at: later)
        try TimeEngine.advance(&state, to: later.addingTimeInterval(60), database: db())
        XCTAssertEqual(state.pet.activeMinutes, 1)
    }
    func testSleepScheduleWrapsMidnight() {
        XCTAssertTrue(TimeEngine.isSleepHour(23, sleep: 21, wake: 7))
        XCTAssertTrue(TimeEngine.isSleepHour(6, sleep: 21, wake: 7))
        XCTAssertFalse(TimeEngine.isSleepHour(7, sleep: 21, wake: 7))
        XCTAssertFalse(TimeEngine.isSleepHour(20, sleep: 21, wake: 7))
        XCTAssertTrue(TimeEngine.isSleepHour(13, sleep: 9, wake: 17))
    }
    func testHomeTimeZoneControlsSleep() throws {
        let content = try db()
        var g = try hatched(); g.homeTimeZone = "Australia/Sydney"
        // Construct 22:00 in the saved home zone, regardless of the test host timezone.
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: g.homeTimeZone)!
        let date = c.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 22))!
        g.lastTick = date; g.highWatermark = date; g.pets[0].lightsOff = true
        try TimeEngine.advance(&g, to: date.addingTimeInterval(3600), database: content)
        XCTAssertTrue(g.pet.sleeping); XCTAssertEqual(g.pet.stats.fullness, 80)
        XCTAssertEqual(g.pet.stats.mistakes, 0)
    }
    func testDaylightSavingOfflineMatchesMinuteReplay() throws {
        let content = try db()
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Australia/Sydney")!
        let start = c.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 0))!
        var one = try hatched(); one.homeTimeZone = "Australia/Sydney"
        one.lastTick = start; one.highWatermark = start; one.pets[0].lightsOff = true
        var many = one
        try TimeEngine.advance(&one, to: start.addingTimeInterval(8*3600), database: content)
        for minute in 1...480 {
            try TimeEngine.advance(&many, to: start.addingTimeInterval(Double(minute*60)), database: content)
        }
        XCTAssertEqual(one, many)
    }
    func testNeglectDeathAndRebirthKeepDex() throws {
        var state = try hatched("agumon")
        try TimeEngine.advance(&state, to: noon.addingTimeInterval(120 * 86400), database: db())
        XCTAssertEqual(state.pet.life, .dead)
        XCTAssertTrue(state.pet.history.contains { $0.kind == "death" })
        let oldID = state.pet.id
        try GameEngine.perform(.rebirth("founder"), state: &state, database: db(), at: state.highWatermark)
        XCTAssertNotEqual(oldID, state.pet.id); XCTAssertEqual(state.pets.count, 2)
        XCTAssertEqual(state.dex["agumon"], .raised); XCTAssertTrue(state.pet.isEgg)
    }
    func testFeedingOverfeedingAndCleaning() throws {
        var state = try hatched()
        try GameEngine.perform(.feed("meat"), state: &state, database: db(), at: noon)
        XCTAssertEqual(state.pet.stats.fullness, 100); XCTAssertEqual(state.pet.stats.health, 97)
        for _ in 0..<3 { try GameEngine.perform(.feed("protein"), state: &state, database: db(), at: noon) }
        XCTAssertEqual(state.pet.stats.meals, 4); XCTAssertEqual(state.pet.stats.waste, 1)
        try GameEngine.perform(.clean, state: &state, database: db(), at: noon)
        XCTAssertEqual(state.pet.stats.waste, 0)
        XCTAssertThrowsError(try GameEngine.perform(.feed("fruit"), state: &state, database: db(), at: noon))
    }
    func testOldArchiveCannotCreateParallelLivePets() throws {
        var state = try hatched("agumon")
        state.pets[0].life = .dead
        let archiveID = state.pet.id
        try GameEngine.perform(.rebirth("founder"), state: &state, database: db(), at: noon)
        try GameEngine.perform(.selectPet(archiveID), state: &state, database: db(), at: noon)
        XCTAssertThrowsError(try GameEngine.perform(.rebirth("founder"), state: &state, database: db(), at: noon))
        XCTAssertEqual(state.pets.count, 2)
    }
    func testDirtCausesIllnessAndMedicineWorks() throws {
        var state = try hatched("agumon"); state.pets[0].stats.waste = 1
        try TimeEngine.advance(&state, to: noon.addingTimeInterval(120*60), database: db())
        XCTAssertTrue(state.pet.stats.sick); XCTAssertEqual(state.pet.stats.illnesses, 1)
        let at = state.highWatermark
        try GameEngine.perform(.clean, state: &state, database: db(), at: at)
        try GameEngine.perform(.medicine, state: &state, database: db(), at: at)
        XCTAssertFalse(state.pet.stats.sick); XCTAssertEqual(state.pet.stats.health, 100)
    }
    func testBranchUsesCareAndTrainingInsteadOfExperience() throws {
        let content = try db()
        var p = try hatched("koromon").pet; p.stageMinutes = 360
        XCTAssertEqual(try EvolutionEngine.candidate(pet: p, database: content, inventory: [:])?.target, "betamon")
        p.stats.training = 3; p.stats.trainingAttempts = 3; p.stats.mistakes = 2
        XCTAssertEqual(try EvolutionEngine.candidate(pet: p, database: content, inventory: [:])?.target, "agumon")
        p.stats.mistakes = 3
        XCTAssertEqual(try EvolutionEngine.candidate(pet: p, database: content, inventory: [:])?.target, "betamon")
    }
    func testEvolutionConsumesItemExactlyOnce() throws {
        var g = try hatched("greymon")
        g.pets[0].stageMinutes = 2879; g.pets[0].stats.training = 20; g.pets[0].stats.trainingAttempts = 20
        g.pets[0].stats.battles = 10; g.pets[0].stats.wins = 6
        g.inventory["evolution-chip"] = 1
        try TimeEngine.advance(&g, to: noon.addingTimeInterval(60), database: db())
        XCTAssertEqual(g.pet.speciesID, "metalgreymon"); XCTAssertEqual(g.inventory["evolution-chip"], 0)
        let evolved = g
        try TimeEngine.advance(&g, to: noon.addingTimeInterval(60), database: db())
        XCTAssertEqual(evolved, g)
    }
    func testTrainingNeedsTimingAndCannotReplayCompletion() throws {
        var g = try hatched(); try TrainingEngine.begin(&g, at: noon)
        let id = try XCTUnwrap(g.training?.id)
        for seconds in [0.72, 2.72] { XCTAssertNil(try TrainingEngine.tap(&g, sessionID: id, at: noon.addingTimeInterval(seconds))) }
        let score = try TrainingEngine.tap(&g, sessionID: id, at: noon.addingTimeInterval(4.72))
        XCTAssertEqual(score, 100); XCTAssertEqual(g.pet.stats.training, 1)
        XCTAssertEqual(g.pet.stats.trainingAttempts, 1)
        XCTAssertThrowsError(try TrainingEngine.tap(&g, sessionID: id, at: noon.addingTimeInterval(6.72)))
        XCTAssertEqual(g.pet.stats.training, 1)
    }
    func testFailedTrainingIsRecordedAndFastDoubleTapRejected() throws {
        var g = try hatched(); try TrainingEngine.begin(&g, at: noon)
        let id = try XCTUnwrap(g.training?.id)
        _ = try TrainingEngine.tap(&g, sessionID: id, at: noon)
        XCTAssertThrowsError(try TrainingEngine.tap(&g, sessionID: id, at: noon.addingTimeInterval(0.1)))
        _ = try TrainingEngine.tap(&g, sessionID: id, at: noon.addingTimeInterval(2))
        XCTAssertEqual(try TrainingEngine.tap(&g, sessionID: id, at: noon.addingTimeInterval(4)), 0)
        XCTAssertEqual(g.pet.stats.training, 0); XCTAssertEqual(g.pet.stats.trainingAttempts, 1)
    }
    func testSeededBattleHasStableResultAndBoundedTurns() throws {
        var a = try hatched("agumon"); var b = a
        let ra = try BattleEngine.fight(&a, opponentID: "betamon", database: db(), at: noon)
        let rb = try BattleEngine.fight(&b, opponentID: "betamon", database: db(), at: noon)
        XCTAssertEqual(ra.log, rb.log); XCTAssertEqual(ra.won, rb.won)
        XCTAssertLessThanOrEqual(ra.turns, 40); XCTAssertEqual(a.pet.stats.battles, 1)
        XCTAssertEqual(a.dex["betamon"], .encountered)
        XCTAssertEqual(a.pet.stats.energy, 85); XCTAssertGreaterThan(a.pet.stats.health, 0)
    }
    func testBabyCannotBattleAndAttributeTriangle() throws {
        var state = try hatched()
        XCTAssertThrowsError(try BattleEngine.fight(&state, opponentID: "agumon", database: db(), at: noon))
        XCTAssertEqual(BattleEngine.multiplier(attacker: .vaccine, defender: .virus), 1.25)
        XCTAssertEqual(BattleEngine.multiplier(attacker: .virus, defender: .vaccine), 0.8)
        XCTAssertEqual(BattleEngine.multiplier(attacker: .unknown, defender: .virus), 1)
    }
    func testAdventureCollisionAndUniqueChest() throws {
        var g = try hatched("agumon")
        XCTAssertThrowsError(try AdventureEngine.move(&g, dx: -1, dy: 0, database: db(), at: noon))
        XCTAssertEqual(g.adventure.x, 1); XCTAssertEqual(g.pet.stats.energy, 100)
        g.adventure.x = 2; g.adventure.y = 3
        _ = try AdventureEngine.move(&g, dx: 0, dy: 1, database: db(), at: noon)
        XCTAssertEqual(g.inventory["fruit"], 2)
        _ = try AdventureEngine.move(&g, dx: 0, dy: -1, database: db(), at: noon)
        _ = try AdventureEngine.move(&g, dx: 0, dy: 1, database: db(), at: noon)
        XCTAssertEqual(g.inventory["fruit"], 2)
    }
    func testQuestRewardIsOnceOnly() throws {
        var g = try hatched("agumon")
        for (x,y) in [(11,1),(2,4),(10,6)] {
            g.adventure.x = x-1; g.adventure.y = y
            _ = try AdventureEngine.move(&g, dx: 1, dy: 0, database: db(), at: noon)
        }
        XCTAssertTrue(g.adventure.questComplete); XCTAssertEqual(g.inventory["evolution-chip"], 1)
        g.adventure.x = 9; g.adventure.y = 6
        _ = try AdventureEngine.move(&g, dx: 1, dy: 0, database: db(), at: noon)
        XCTAssertEqual(g.inventory["evolution-chip"], 1)
    }
    func testSaveRoundtripAndBackupRecovery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore(directory: directory, database: try db())
        XCTAssertNil(try store.load())
        var g = try game(); try store.save(g)
        XCTAssertEqual(try store.load()?.state, g)
        let first = g
        g.inventory["fruit"] = 3; try store.save(g)
        try Data("damaged".utf8).write(to: store.primaryURL)
        let recovered = try XCTUnwrap(store.load())
        XCTAssertTrue(recovered.recoveredBackup); XCTAssertEqual(recovered.state, first)
        try store.save(recovered.state)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("world.damaged.json").path))
        XCTAssertEqual(try store.decode(Data(contentsOf: store.backupURL)).state, first)
    }
    func testV1MigrationAndFutureVersionRejection() throws {
        let store = SaveStore(directory: URL(fileURLWithPath: "/unused"), database: try db())
        let data = try store.encode(game())
        func versioned(_ version: Int) throws -> Data {
            var e = try JSONSerialization.jsonObject(with: data) as! [String:Any]
            let payload = Data(base64Encoded: e["payload"] as! String)!
            var p = try JSONSerialization.jsonObject(with: payload) as! [String:Any]
            p["schemaVersion"] = version
            if version == 1 { p.removeValue(forKey: "highWatermark") }
            let bytes = try JSONSerialization.data(withJSONObject: p, options: [.sortedKeys])
            e["payload"] = bytes.base64EncodedString(); e["checksum"] = SaveStore.checksum(bytes)
            return try JSONSerialization.data(withJSONObject: e)
        }
        let migrated = try store.decode(versioned(1))
        XCTAssertTrue(migrated.migrated); XCTAssertEqual(migrated.state.schemaVersion, 2)
        XCTAssertEqual(migrated.state.highWatermark, migrated.state.lastTick)
        XCTAssertThrowsError(try store.decode(versioned(99))) { XCTAssertEqual($0 as? GameError, .futureSave(99)) }
    }
    func testChecksumAndInvalidStateAreRejected() throws {
        let store = SaveStore(directory: URL(fileURLWithPath: "/unused"), database: try db())
        var e = try JSONSerialization.jsonObject(with: store.encode(game())) as! [String:Any]
        e["checksum"] = "wrong"
        XCTAssertThrowsError(try store.decode(JSONSerialization.data(withJSONObject: e)))
        var invalid = try game(); invalid.pets[0].stats.health = -1
        XCTAssertThrowsError(try store.encode(invalid))
    }
}
