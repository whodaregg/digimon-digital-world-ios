import XCTest
@testable import DigitalWorldCore

final class RoomEndpointTests: XCTestCase {
    func testRoomsAcceptTLSAndPrivateLANWithoutAppleServices() throws {
        XCTAssertEqual(try RoomEndpoint.url(server: "https://relay.example.com",room: "abc123").absoluteString,"wss://relay.example.com/room/ABC123")
        XCTAssertEqual(try RoomEndpoint.url(server: "ws://192.168.1.10:8765",room: "ABC123").host,"192.168.1.10")
        XCTAssertEqual(try RoomEndpoint.url(server: "ws://localhost:8765",room: "ABC123").scheme,"ws")
    }
    func testPublicPlaintextCredentialsAndInvalidCodesAreRejected() throws {
        for server in ["ws://example.com","ws://192.168.1.10.example.com","ws://8.8.8.8","file:///private","wss://user:password@example.com","wss://example.com?token=secret"] {
            XCTAssertThrowsError(try RoomEndpoint.url(server: server,room: "ABC123"))
        }
        for code in ["short","../../a","房间123",String(repeating: "A",count: 33)] {
            XCTAssertThrowsError(try RoomEndpoint.url(server: "wss://example.com",room: code))
        }
    }
}

final class ConnectionTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_446_400)
    func game(_ species: String) throws -> GameState {
        var g = try DeviceRegistry.newGame(database: .bundled(),deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
        g.pets[0].isEgg = false; g.pets[0].speciesID = species; g.pets[0].stats.dp = 10
        g.pets[0].dmc!.strengthHearts = 4; g.pets[0].stats.strength = 100; g.pets[0].stats.weight = 30
        return g
    }
    func testBothPeersDeriveOppositeResultsAndSameReceipt() throws {
        let db = try ContentDatabase.bundled(),a = try ConnectionEngine.fighter(for: game("agumon"),database: db),b = try ConnectionEngine.fighter(for: game("betamon"),database: db)
        let ab = try ConnectionEngine.resolve(player: a,opponent: b,database: db),ba = try ConnectionEngine.resolve(player: b,opponent: a,database: db)
        XCTAssertEqual(ab.id,ba.id); XCTAssertNotEqual(ab.playerWon,ba.playerWon)
        XCTAssertEqual(ab.hits.count,7); XCTAssertEqual(ab.hits.prefix(6),[.player,.opponent,.player,.opponent,.player,.opponent])
    }
    func testReceiptPreventsDuplicateCostsAndEvolutionBattleCredit() throws {
        let db = try ContentDatabase.bundled(); var g = try game("agumon")
        let a = try ConnectionEngine.fighter(for: g,database: db),b = try ConnectionEngine.fighter(for: game("betamon"),database: db)
        let result = try ConnectionEngine.resolve(player: a,opponent: b,database: db)
        try ConnectionEngine.apply(result,player: a,opponent: b,state: &g,database: db,at: now)
        XCTAssertEqual(g.pet.stats.dp,9); XCTAssertEqual(g.pet.stats.battles,1); XCTAssertEqual(g.pet.dmc!.stageBattles,1)
        let saved = g
        XCTAssertThrowsError(try ConnectionEngine.apply(result,player: a,opponent: b,state: &g,database: db,at: now))
        XCTAssertEqual(g,saved)
    }
    func testSandboxFormalAndStaleSnapshotsAreRejectedAtomically() throws {
        let db = try ContentDatabase.bundled(); var g = try game("agumon"),other = try game("betamon")
        other.sessionStyle = .sandbox; other.developerModifiedAt = now
        let a = try ConnectionEngine.fighter(for: g,database: db),b = try ConnectionEngine.fighter(for: other,database: db)
        XCTAssertThrowsError(try ConnectionEngine.resolve(player: a,opponent: b,database: db))
        other.sessionStyle = .enhanced; other.developerModifiedAt = nil
        let legal = try ConnectionEngine.fighter(for: other,database: db),r = try ConnectionEngine.resolve(player: a,opponent: legal,database: db)
        g.pets[0].dmc!.strengthHearts = 3; g.pets[0].stats.strength = 75; let saved = g
        XCTAssertThrowsError(try ConnectionEngine.apply(r,player: a,opponent: legal,state: &g,database: db,at: now)); XCTAssertEqual(g,saved)
    }
    func testUnsupportedProfilesAndModifiedFormalFilesCannotEnter() throws {
        let db = try ContentDatabase.bundled(); var g = try game("agumon")
        g.developerModifiedAt = now
        XCTAssertThrowsError(try ConnectionEngine.fighter(for: g,database: db))
        g.sessionStyle = .sandbox
        var snapshot = try ConnectionEngine.fighter(for: g,database: db); snapshot.deviceID = "pendulum"
        XCTAssertThrowsError(try ConnectionEngine.validate(snapshot,database: db))
    }
}
