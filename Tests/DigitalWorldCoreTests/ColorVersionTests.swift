import XCTest
@testable import DigitalWorldCore

final class ColorVersionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_446_400)
    func testVersionTwoHasIndependentEggRosterThresholdsAndQuest() throws {
        let db = try ContentDatabase.bundled()
        var game = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver2",eggID: "dmc-v2-egg",now: now)
        try TimeEngine.advance(&game,to: now.addingTimeInterval(8),database: db)
        XCTAssertEqual(game.pet.speciesID,"punimon")
        try TimeEngine.advance(&game,to: now.addingTimeInterval(608),database: db)
        XCTAssertEqual(game.pet.speciesID,"tsunomon")
        let rules = try XCTUnwrap(db.colorRules(for: "dmc-ver2"))
        XCTAssertEqual(rules.roster.count,18)
        XCTAssertEqual(rules.areas[0].opponents.map(\.speciesID),["elecmon","gabumon","yukidarumon"])
        XCTAssertEqual(rules.roster["gabumon"]?.sleepHour,21)
        try DeveloperEngine.perform(.selectSpecies("gabumon"),state: &game,database: db,at: game.highWatermark)
        game.pets[0].dmc!.stageMistakes = 0; game.pets[0].dmc!.stageTrainings = 47
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: game.pet,rules: rules)?.target,"angemon")
        game.pets[0].dmc!.stageTrainings = 48
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: game.pet,rules: rules)?.target,"kabuterimon")
        try DMCV1Engine.swapBackup(&game,at: game.highWatermark)
        XCTAssertEqual(game.pet.speciesID,"punimon"); XCTAssertEqual(game.pet.eggID,"dmc-v2-egg")
        try db.validateSave(game)
    }
    func testCrossVersionCommunicationJogressEvolvesBothPartnersOnce() throws {
        let db = try ContentDatabase.bundled()
        var a = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        var b = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver2",eggID: "dmc-v2-egg",now: now)
        try DeveloperEngine.perform(.selectSpecies("blitzgreymon"),state: &a,database: db,at: now)
        try DeveloperEngine.perform(.selectSpecies("cresgarurumon"),state: &b,database: db,at: now)
        a.sessionStyle = .sandbox; b.sessionStyle = .sandbox
        let originalA = a.pet.id,originalB = b.pet.id
        let fa = try ConnectionEngine.fighter(for: a,database: db),fb = try ConnectionEngine.fighter(for: b,database: db)
        let ra = try ConnectionEngine.resolve(player: fa,opponent: fb,database: db)
        let rb = try ConnectionEngine.resolve(player: fb,opponent: fa,database: db)
        XCTAssertEqual(ra.id,rb.id); XCTAssertNotEqual(ra.playerWon,rb.playerWon)
        try ConnectionEngine.apply(ra,player: fa,opponent: fb,state: &a,database: db,at: now)
        try ConnectionEngine.apply(rb,player: fb,opponent: fa,state: &b,database: db,at: now)
        XCTAssertEqual(a.pet.speciesID,"omegamon-alter-s"); XCTAssertEqual(b.pet.speciesID,"omegamon-alter-s")
        XCTAssertEqual(a.pet.id,originalA); XCTAssertEqual(b.pet.id,originalB)
        XCTAssertEqual(a.pet.stats.battles,1); XCTAssertEqual(b.pet.stats.battles,1)
        let saved = a
        XCTAssertThrowsError(try ConnectionEngine.apply(ra,player: fa,opponent: fb,state: &a,database: db,at: now))
        XCTAssertEqual(a,saved)
        XCTAssertTrue(CollectionManager.entries(in: [a,b]).isEmpty)
    }
}
