import XCTest
@testable import DigitalWorldCore

final class QuestReplayTests: XCTestCase {
    private func record(_ hits: [BattleSide],won: Bool) -> BattleRecord {
        BattleRecord(id: UUID(),date: Date(timeIntervalSince1970: 0),opponent: "betamon",won: won,
                     turns: hits.count,hpRemaining: 0,log: hits.map { $0 == .player ? "攻击命中" : "受到攻击" },hitSequence: hits)
    }
    func testAlternatingOutcomeReplayAndThirdHitStops() throws {
        let r = record([.player,.opponent,.player,.opponent,.player],won: true)
        let rounds = try QuestReplay.rounds(for: r)
        XCTAssertEqual(rounds.map(\.number),[1,2,3,4,5])
        XCTAssertEqual(rounds.map(\.playerHits),[1,1,2,2,3])
        XCTAssertEqual(rounds.map(\.opponentHits),[0,1,1,2,2])
        XCTAssertEqual(rounds.map(\.winner),r.hitSequence!)
        XCTAssertEqual(try QuestReplay.rounds(for: record([.opponent,.opponent,.opponent],won: false)).last?.opponentHits,3)
    }
    func testOldRecordDecodesWithoutSequenceAndKeepsOutcome() throws {
        var old = record([.player,.opponent,.player,.player],won: true); old.hitSequence = nil
        let bytes = try JSONEncoder().encode(old)
        XCTAssertFalse(String(decoding: bytes,as: UTF8.self).contains("hitSequence"))
        let restored = try JSONDecoder().decode(BattleRecord.self,from: bytes)
        XCTAssertEqual(try QuestReplay.rounds(for: restored).map(\.winner),[.player,.opponent,.player,.player])
        XCTAssertEqual(try JSONDecoder().decode(BattleRecord.self,from: JSONEncoder().encode(record([.player,.player,.player],won: true))).hitSequence,[.player,.player,.player])
    }
    func testRejectsTruncatedContradictoryAndExtraHits() throws {
        for r in [record([.player,.player],won: true),record([.player,.player,.player],won: false),
                  record([.player,.player,.player,.opponent],won: true),record([.player,.opponent,.player],won: true)] {
            XCTAssertThrowsError(try QuestReplay.rounds(for: r))
        }
        var malformed = record([.player,.player,.player],won: true); malformed.hitSequence = nil; malformed.log[0] = "未知记录"
        XCTAssertThrowsError(try QuestReplay.rounds(for: malformed))
    }
    func testEveryAreaPersistsReplayWithoutAdditionalCostsOrRandomness() throws {
        let db = try ContentDatabase.bundled(), now = Date(timeIntervalSince1970: 1_800_446_400)
        for area in 1...8 {
            var g = try DeviceRegistry.newGame(database: db,deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: now)
            g.pets[0].isEgg = false; g.pets[0].speciesID = "agumon"; g.pets[0].stats.dp = 20
            g.pets[0].stats.weight = 30; g.pets[0].dmc!.hungerHearts = 4; g.pets[0].dmc!.strengthHearts = 4
            g.pets[0].developerTuning = DeveloperTuning(); g.pets[0].developerTuning!.power = 1_000_000
            g.dmc!.clearedAreas = Set(1..<area); g.rng = 1
            DMCV1Engine.sync(&g.pets[0])
            let result = try DMCV1Engine.quest(&g,areaID: area,database: db,at: now)
            XCTAssertEqual(result.playerSpeciesID,"agumon")
            if area == 1 { XCTAssertTrue(result.cleared); XCTAssertEqual(result.records.count,3) }
            let saved = g
            for r in result.records {
                XCTAssertNotNil(r.hitSequence)
                let rounds = try QuestReplay.rounds(for: r)
                XCTAssertEqual(rounds.last?.winner,r.won ? .player : .opponent)
                XCTAssertEqual(rounds.count,r.turns)
                _ = try QuestReplay.rounds(for: r)
            }
            XCTAssertEqual(g,saved); XCTAssertEqual(g.pet.stats.dp,19); XCTAssertEqual(g.pet.stats.weight,24)
        }
    }
}
