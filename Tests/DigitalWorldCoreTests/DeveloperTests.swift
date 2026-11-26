import XCTest
@testable import DigitalWorldCore

final class DeveloperTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_446_400)
    func game(legacy: Bool = false) throws -> (ContentDatabase,GameState) {
        let db = try ContentDatabase.bundled()
        let g = try DeviceRegistry.newGame(database: db,deviceID: legacy ? "ultimate-lab" : "dmc-ver1",eggID: legacy ? "founder" : "dmc-v1-egg",now: now)
        return (db,g)
    }
    func testSelectEveryBundledSpeciesIncludingQuestOnlyNPCAndRoundTrip() throws {
        var (db,g) = try game()
        let id = g.pet.id, egg = g.pet.eggID
        let store = SaveStore(directory: URL(fileURLWithPath: "/unused"),database: db)
        for species in db.species {
            try DeveloperEngine.perform(.selectSpecies(species.id),state: &g,database: db,at: now)
            XCTAssertEqual(g.pet.id,id); XCTAssertEqual(g.pet.eggID,egg)
            XCTAssertEqual(g.pet.speciesID,species.id); XCTAssertFalse(g.pet.isEgg)
            XCTAssertEqual(g.pet.dmc!.hungerHearts,4)
            XCTAssertEqual(g.dex[species.id],.raised); XCTAssertNotNil(g.developerModifiedAt)
            XCTAssertEqual(try store.decode(store.encode(g)).state,g)
        }
        XCTAssertEqual(g.pet.speciesID,"omegamon-alter-s")
        XCTAssertFalse(db.dmcV1!.evolutions.contains { $0.target == "omegamon-alter-s" })
    }
    func testGrantKnownAndCustomItemsWithTransactionalBounds() throws {
        var (db,g) = try game()
        let catalog = DeveloperEngine.itemCatalog(database: db,state: g)
        XCTAssertEqual(catalog.count,8); XCTAssertEqual(catalog["evolution-chip"],"进化芯片")
        try DeveloperEngine.perform(.grantItem("evolution-chip",8),state: &g,database: db,at: now)
        try DeveloperEngine.perform(.grantItem("future-item",999999),state: &g,database: db,at: now)
        XCTAssertEqual(g.inventory["evolution-chip"],8)
        let snapshot = g
        for action in [DeveloperAction.grantItem("future-item",1),.grantItem("meat",0),.grantItem("",1),.grantItem("bad id",1),.grantItem("meat",Int.max)] {
            XCTAssertThrowsError(try DeveloperEngine.perform(action,state: &g,database: db,at: now))
            XCTAssertEqual(g,snapshot)
        }
    }
    func testNumericEditsRejectInvalidRelationshipsWithoutPartialWrites() throws {
        var (db,g) = try game()
        try DeveloperEngine.perform(.selectSpecies("agumon"),state: &g,database: db,at: now)
        let snapshot = g
        for values: [DeveloperField:Int] in [[.wins: 3,.battles: 2],[.training: 2,.trainingAttempts: 1],[.weight: 100],[.hungerHearts: 5],[.power: Int.max],[.hp: 100]] {
            var edit = DeveloperPetEdit(pet: g.pet); edit.values = values
            XCTAssertThrowsError(try DeveloperEngine.perform(.edit(edit),state: &g,database: db,at: now))
            XCTAssertEqual(g,snapshot)
        }
        var edit = DeveloperPetEdit(pet: g.pet)
        edit.values = [.battles:10,.wins:7,.stageTrainings:32,.stageMistakes:4,.weight:99,.activeMinutes:500]
        edit.life = .frozen; edit.traited = true
        try DeveloperEngine.perform(.edit(edit),state: &g,database: db,at: now)
        XCTAssertEqual(g.pet.stats.winRate,0.7); XCTAssertEqual(g.pet.dmc!.effortHearts,4)
        XCTAssertEqual(g.pet.life,.frozen); XCTAssertTrue(g.pet.dmc!.traited)
    }
    func testPowerOverrideChangesActualQuestOutcome() throws {
        var (db,weak) = try game()
        try DeveloperEngine.perform(.selectSpecies("agumon"),state: &weak,database: db,at: now)
        var edit = DeveloperPetEdit(pet: weak.pet); edit.values = [.power:0,.strengthHearts:0]
        try DeveloperEngine.perform(.edit(edit),state: &weak,database: db,at: now)
        var strong = weak
        edit.values[.power] = 1_000_000
        try DeveloperEngine.perform(.edit(edit),state: &strong,database: db,at: now)
        let a = try DMCV1Engine.quest(&weak,areaID: 1,database: db,at: now)
        let b = try DMCV1Engine.quest(&strong,areaID: 1,database: db,at: now)
        XCTAssertFalse(a.records[0].won); XCTAssertTrue(b.records[0].won)
        XCTAssertEqual(db.dmcV1!.roster["agumon"]!.power,30)
    }
    func testDPOverridePersistsAndProteinUsesNewLimit() throws {
        var (db,g) = try game()
        try DeveloperEngine.perform(.selectSpecies("agumon"),state: &g,database: db,at: now)
        var edit = DeveloperPetEdit(pet: g.pet); edit.values = [.dpCapacity:99,.dp:98]
        try DeveloperEngine.perform(.edit(edit),state: &g,database: db,at: now)
        for _ in 0..<4 { try GameEngine.perform(.feed("protein"),state: &g,database: db,at: now) }
        XCTAssertEqual(g.pet.stats.dp,99)
        let store = SaveStore(directory: URL(fileURLWithPath: "/unused"),database: db)
        XCTAssertEqual(try store.decode(store.encode(g)).state,g)
        edit.values = [.dpCapacity:20,.dp:99]
        XCTAssertThrowsError(try DeveloperEngine.perform(.edit(edit),state: &g,database: db,at: now))
    }
    func testLegacyOverridesChangeActualBattleWithoutRewritingDatabase() throws {
        var (db,g) = try game(legacy: true)
        try DeveloperEngine.perform(.selectSpecies("agumon"),state: &g,database: db,at: now)
        var edit = DeveloperPetEdit(pet: g.pet)
        edit.values = [.hp:1_000_000,.attack:1_000_000,.speed:1_000_000,.critical:0]
        try DeveloperEngine.perform(.edit(edit),state: &g,database: db,at: now)
        let result = try BattleEngine.fight(&g,opponentID: "betamon",database: db,at: now)
        XCTAssertTrue(result.won); XCTAssertEqual(result.turns,1); XCTAssertEqual(result.hpRemaining,1_000_000)
        XCTAssertLessThan(try db.species("agumon").stats.attack,1_000_000)
        XCTAssertThrowsError(try DeveloperField.hungerHearts.value(pet: g.pet,database: db))
    }
    func testStaleDraftAndClockRollbackAreRejected() throws {
        var (db,g) = try game()
        try DeveloperEngine.perform(.selectSpecies("agumon"),state: &g,database: db,at: now)
        var draft = DeveloperPetEdit(pet: g.pet); draft.values = [.weight:99]
        try DeveloperEngine.perform(.selectSpecies("greymon"),state: &g,database: db,at: now)
        let snapshot = g
        XCTAssertThrowsError(try DeveloperEngine.perform(.edit(draft),state: &g,database: db,at: now))
        XCTAssertEqual(g,snapshot)
        XCTAssertThrowsError(try DeveloperEngine.perform(.grantItem("meat",1),state: &g,database: db,at: now.addingTimeInterval(-1)))
        XCTAssertEqual(g,snapshot)
    }
    func testSelectingSpeciesCancelsTrainingAndKeepsBackupPet() throws {
        var (db,g) = try game()
        try DeveloperEngine.perform(.selectSpecies("agumon"),state: &g,database: db,at: now)
        let backup = g.pet.id
        try DMCV1Engine.swapBackup(&g,at: now)
        try DeveloperEngine.perform(.selectSpecies("agumon"),state: &g,database: db,at: now)
        try DMCV1Engine.beginTraining(&g,at: now)
        try DeveloperEngine.perform(.selectSpecies("blitzgreymon"),state: &g,database: db,at: now)
        XCTAssertNil(g.training); XCTAssertEqual(g.dmc!.backupPetID,backup)
        XCTAssertEqual(g.pets[0].life,.frozen)
        try db.validateSave(g)
    }
    func testV3SaveMigratesWithoutAddingTestFlags() throws {
        let (db,g) = try game()
        let store = SaveStore(directory: URL(fileURLWithPath: "/unused"),database: db)
        var envelope = try JSONSerialization.jsonObject(with: store.encode(g)) as! [String:Any]
        var payload = try JSONSerialization.jsonObject(with: Data(base64Encoded: envelope["payload"] as! String)!) as! [String:Any]
        payload["schemaVersion"] = 3; payload.removeValue(forKey: "developerModifiedAt")
        let data = try JSONSerialization.data(withJSONObject: payload,options: [.sortedKeys])
        envelope["payload"] = data.base64EncodedString(); envelope["checksum"] = SaveStore.checksum(data)
        let loaded = try store.decode(JSONSerialization.data(withJSONObject: envelope))
        XCTAssertTrue(loaded.migrated); XCTAssertEqual(loaded.state.schemaVersion,GameState.currentVersion)
        XCTAssertNil(loaded.state.developerModifiedAt); XCTAssertNil(loaded.state.pet.developerTuning)
    }
}
