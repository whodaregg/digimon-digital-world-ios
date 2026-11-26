import XCTest
@testable import DigitalWorldCore

final class ArchiveCareTests: XCTestCase {
    private let noon = Date(timeIntervalSince1970: 1_800_446_400)

    func testEveryUploadedCharacterCanBeAdoptedFedAndSaved() throws {
        let database = try ContentDatabase.bundled()
        let roster = database.species.filter { $0.devices.contains(ArchiveCareEngine.deviceID) }
        XCTAssertEqual(roster.count, 844)
        let store = SaveStore(directory: URL(fileURLWithPath: "/unused"), database: database)
        for species in roster {
            var game = try ArchiveCareEngine.adopt(species.id, database: database, at: noon)
            XCTAssertEqual(game.pet.speciesID, species.id)
            XCTAssertFalse(game.pet.isEgg)
            XCTAssertEqual(game.dex[species.id], .raised)
            try GameEngine.perform(.feed("meat"), state: &game, database: database, at: noon)
            XCTAssertEqual(game.pet.stats.meals, 1)
            let restored = try store.decode(store.encode(game)).state
            XCTAssertEqual(restored.pet.id, game.pet.id)
            XCTAssertEqual(restored.pet.speciesID, species.id)
        }
    }

    func testArchiveTrainingBattleAndOfflineCareUseRealEngines() throws {
        let database = try ContentDatabase.bundled()
        let species = try XCTUnwrap(database.species.first { $0.name == "Agumon (Black) X" })
        var game = try ArchiveCareEngine.adopt(species.id, database: database, at: noon)
        try TrainingEngine.begin(&game, at: noon)
        let session = try XCTUnwrap(game.training)
        for offset in [0.72, 2.72, 4.72] {
            _ = try TrainingEngine.tap(&game, sessionID: session.id, at: noon.addingTimeInterval(offset))
        }
        XCTAssertEqual(game.pet.stats.trainingAttempts, 1)
        _ = try BattleEngine.fight(&game, opponentID: "agumon", database: database, at: noon.addingTimeInterval(5))
        XCTAssertEqual(game.pet.stats.battles, 1)
        try TimeEngine.advance(&game, to: noon.addingTimeInterval(7200), database: database)
        XCTAssertEqual(game.pet.activeMinutes, 120)
        XCTAssertGreaterThan(game.pet.stats.waste, 0)
        try database.validateSave(game)
        XCTAssertThrowsError(try ArchiveCareEngine.adopt("agumon", database: database, at: noon))
    }
}
