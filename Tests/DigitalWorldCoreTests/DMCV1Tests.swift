import XCTest
@testable import DigitalWorldCore

final class DMCV1Tests: XCTestCase {
    let noon = Date(timeIntervalSince1970: 1_800_446_400)
    func db() throws -> ContentDatabase { try .bundled() }
    func game(_ species: String? = nil) throws -> GameState {
        var g = try DeviceRegistry.newGame(database: db(),deviceID: "dmc-ver1",eggID: "dmc-v1-egg",now: noon)
        if let species {
            g.pets[0].isEgg = false; g.pets[0].speciesID = species; g.pets[0].evolutionHistory = [species]
            let rule = try XCTUnwrap(db().dmcV1?.roster[species])
            g.pets[0].stats.weight = rule.minimumWeight; g.pets[0].stats.dp = rule.maxDP
            g.pets[0].dmc!.hungerHearts = 4; g.pets[0].dmc!.strengthHearts = 4
            DMCV1Engine.sync(&g.pets[0])
        }
        return g
    }
    func testEightSecondHatchAndTenMinuteFirstEvolution() throws {
        let content = try db(); var g = try game()
        XCTAssertEqual(g.mode,.original); XCTAssertEqual(g.settings.display,.color)
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(7.99),database: content)
        XCTAssertTrue(g.pet.isEgg)
        XCTAssertEqual(try TimeEngine.advance(&g,to: noon.addingTimeInterval(8),database: content).hatchings,1)
        XCTAssertFalse(g.pet.isEgg); XCTAssertEqual(g.pet.stats.dp,0)
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(607.9),database: content)
        XCTAssertEqual(g.pet.speciesID,"botamon")
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(608),database: content)
        XCTAssertEqual(g.pet.speciesID,"koromon"); XCTAssertEqual(g.pet.stageMinutes,0)
    }
    func testFrequentReopensEqualOfflineIncludingHatchAndCalls() throws {
        let content = try db(); var a = try game(); var b = a
        for second in stride(from: 1,through: 8*3600+19,by: 13) {
            try TimeEngine.advance(&a,to: noon.addingTimeInterval(Double(second)),database: content)
        }
        let end = noon.addingTimeInterval(Double(8*3600+19))
        try TimeEngine.advance(&a,to: end,database: content); try TimeEngine.advance(&b,to: end,database: content)
        XCTAssertEqual(a,b)
    }
    func testFourHeartsAndProteinRestoresOneDPPerFour() throws {
        let content = try db(); var g = try game("agumon")
        g.pets[0].dmc!.hungerHearts = 0; g.pets[0].dmc!.strengthHearts = 0; g.pets[0].stats.dp = 0
        DMCV1Engine.sync(&g.pets[0])
        for _ in 0..<4 { try GameEngine.perform(.feed("meat"),state: &g,database: content,at: noon) }
        XCTAssertEqual(g.pet.dmc!.hungerHearts,4); XCTAssertEqual(g.pet.stats.weight,24)
        for _ in 0..<4 { try GameEngine.perform(.feed("protein"),state: &g,database: content,at: noon) }
        XCTAssertEqual(g.pet.dmc!.strengthHearts,4); XCTAssertEqual(g.pet.stats.dp,1)
        XCTAssertEqual(g.pet.dmc!.proteinOverdoses,1); XCTAssertEqual(g.pet.stats.weight,32)
        XCTAssertThrowsError(try GameEngine.perform(.feed("fruit"),state: &g,database: content,at: noon))
    }
    func testFullStomachThresholdAndRefusalDoNotDamageHealth() throws {
        let content = try db(); var g = try game("agumon")
        for _ in 0..<10 { try GameEngine.perform(.feed("meat"),state: &g,database: content,at: noon) }
        XCTAssertEqual(g.pet.dmc!.overfeeds,1); XCTAssertTrue(g.pet.dmc!.overfeedExtraCycle)
        let snapshot = g
        XCTAssertThrowsError(try GameEngine.perform(.feed("meat"),state: &g,database: content,at: noon))
        XCTAssertEqual(snapshot,g); XCTAssertEqual(g.pet.stats.health,100)
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(48*60),database: content)
        XCTAssertEqual(g.pet.dmc!.hungerHearts,4)
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(96*60),database: content)
        XCTAssertEqual(g.pet.dmc!.hungerHearts,3)
    }
    func testFailedTrainingCountsAndCancellationDoesNot() throws {
        let content = try db(); var g = try game("agumon")
        g.pets[0].dmc!.strengthHearts = 0; DMCV1Engine.sync(&g.pets[0])
        try TrainingEngine.begin(&g,at: noon)
        for choice in ["A","A","A","B","B"] { _ = try DMCV1Engine.train(&g,choice: choice,database: content,at: noon) }
        XCTAssertNil(g.training); XCTAssertEqual(g.pet.dmc!.stageTrainings,1)
        XCTAssertEqual(g.pet.stats.trainingAttempts,1); XCTAssertEqual(g.pet.stats.training,0)
        XCTAssertEqual(g.pet.dmc!.strengthHearts,0)
        XCTAssertThrowsError(try DMCV1Engine.train(&g,choice: "A",database: content,at: noon))
        try TrainingEngine.begin(&g,at: noon)
        _ = try DMCV1Engine.train(&g,choice: "A",database: content,at: noon)
        g.training = nil
        XCTAssertEqual(g.pet.dmc!.stageTrainings,1)
        for _ in 0..<3 {
            try TrainingEngine.begin(&g,at: noon)
            let pattern = content.dmcV1!.trainingPatterns[g.dmc!.trainingCycle]
            for choice in pattern { _ = try DMCV1Engine.train(&g,choice: String(choice),database: content,at: noon) }
        }
        XCTAssertEqual(g.pet.dmc!.effortHearts,1); XCTAssertEqual(g.pet.dmc!.strengthHearts,3)
        XCTAssertEqual(g.pet.stats.weight,20)
    }
    func testCareCallGraceAndSeparateMistakes() throws {
        let content = try db(); var g = try game("koromon")
        g.pets[0].dmc!.hungerHearts = 0; g.pets[0].dmc!.strengthHearts = 0
        g.pets[0].dmc!.hungerCall = noon; g.pets[0].dmc!.strengthCall = noon
        DMCV1Engine.sync(&g.pets[0])
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(9*60),database: content)
        XCTAssertEqual(g.pet.dmc!.stageMistakes,0)
        try GameEngine.perform(.feed("meat"),state: &g,database: content,at: noon.addingTimeInterval(9*60))
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(10*60),database: content)
        XCTAssertEqual(g.pet.dmc!.stageMistakes,1)
        XCTAssertNil(g.pet.dmc!.strengthCall)
        var both = try game("koromon")
        both.pets[0].dmc!.hungerHearts = 0; both.pets[0].dmc!.strengthHearts = 0
        both.pets[0].dmc!.hungerCall = noon; both.pets[0].dmc!.strengthCall = noon; DMCV1Engine.sync(&both.pets[0])
        try TimeEngine.advance(&both,to: noon.addingTimeInterval(600),database: content)
        XCTAssertEqual(both.pet.dmc!.stageMistakes,2)
    }
    func testOriginalEvolutionBranchBoundariesAndNoExperience() throws {
        let rules = try XCTUnwrap(db().dmcV1); var p = try game("agumon").pet
        p.dmc!.stageTrainings = 31
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"devimon")
        p.dmc!.stageTrainings = 32
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"greymon")
        p.dmc!.stageMistakes = 4; p.dmc!.stageTrainings = 5; p.dmc!.overfeeds = 3; p.dmc!.sleepDisturbances = 4
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"tyrannomon")
        p.dmc!.sleepDisturbances = 6
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"numemon")
        p.dmc!.stageTrainings = 16
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"meramon")
        p.speciesID = "betamon"; p.dmc!.stageMistakes = 0; p.dmc!.stageTrainings = 47
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"meramon")
        p.dmc!.stageTrainings = 48
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"devimon")
    }
    func testHighEvolutionNeedsFreshBattlesAndDoesNotGrantJogress() throws {
        let rules = try XCTUnwrap(db().dmcV1); var p = try game("metalgreymon").pet
        p.dmc!.perfectBattleCount = 100; p.dmc!.megaBattleCount = 14
        XCTAssertNil(DMCV1Engine.evolutionCandidate(pet: p,rules: rules))
        p.dmc!.megaBattleCount = 15
        XCTAssertEqual(DMCV1Engine.evolutionCandidate(pet: p,rules: rules)?.target,"blitzgreymon")
        p.dmc!.stageMistakes = 2
        XCTAssertNil(DMCV1Engine.evolutionCandidate(pet: p,rules: rules))
        p.speciesID = "blitzgreymon"; p.dmc!.stageMistakes = 0
        XCTAssertNil(DMCV1Engine.evolutionCandidate(pet: p,rules: rules))
        XCTAssertEqual([0.39,0.4,0.59,0.6,0.79,0.8].map(DMCV1Engine.evolutionChance),[0,25,25,50,50,100])
    }
    func testQuestRosterOrderAndLockedArea() throws {
        let content = try db(), rules = try XCTUnwrap(content.dmcV1)
        XCTAssertEqual(rules.areas.map { $0.opponents.count },[3,3,3,4,4,4,5,5])
        XCTAssertEqual(rules.areas[0].opponents.map(\.speciesID),["betamon","agumon","meramon"])
        XCTAssertEqual(rules.areas[7].opponents.last?.power,220)
        var g = try game("agumon"); let snapshot = g
        XCTAssertThrowsError(try DMCV1Engine.quest(&g,areaID: 2,database: content,at: noon))
        XCTAssertEqual(g,snapshot)
        XCTAssertThrowsError(try AdventureEngine.move(&g,dx: 1,dy: 0,database: content,at: noon))
        XCTAssertThrowsError(try BattleEngine.fight(&g,opponentID: "betamon",database: content,at: noon))
    }
    func testQuestCostsOnceAndUnlocksOnlyAfterWholeAreaWin() throws {
        let content = try db(); var cleared: GameState?
        for seed in 1...100 {
            var g = try game("blitzgreymon"); g.rng = UInt64(seed); g.pets[0].stats.weight = 60
            let result = try DMCV1Engine.quest(&g,areaID: 1,database: content,at: noon)
            XCTAssertEqual(g.pet.stats.dp,49); XCTAssertEqual(g.pet.stats.weight,54)
            XCTAssertEqual(g.pet.stats.battles,result.records.count)
            XCTAssertTrue(result.records.allSatisfy { (3...5).contains($0.turns) && $0.hpRemaining == 0 })
            XCTAssertEqual(g.dmc!.clearedAreas.contains(1),result.cleared)
            if result.cleared { cleared = g; XCTAssertEqual(result.backgroundUnlocked,"grid"); break }
        }
        var g = try XCTUnwrap(cleared)
        g.pets[0].stats.injured = false
        let again = try DMCV1Engine.quest(&g,areaID: 1,database: content,at: noon)
        XCTAssertNil(again.backgroundUnlocked); XCTAssertTrue(g.dmc!.clearedAreas.contains(1))
    }
    func testDefeatStopsAreaAndRetryRestartsFirstOpponent() throws {
        let content = try db(); var lost: GameState?
        for seed in 1...100 {
            var g = try game("betamon"); g.rng = UInt64(seed)
            let result = try DMCV1Engine.quest(&g,areaID: 1,database: content,at: noon)
            if !result.cleared { lost = g; XCTAssertFalse(g.dmc!.clearedAreas.contains(1)); break }
        }
        var g = try XCTUnwrap(lost); g.pets[0].stats.injured = false
        XCTAssertEqual(try DMCV1Engine.quest(&g,areaID: 1,database: content,at: noon).records.first?.opponent,"betamon")
    }
    func testAttributeAddsFivePercentagePoints() {
        XCTAssertEqual(DMCV1Engine.hitChance(power: 30,enemyPower: 30,attribute: .vaccine,enemyAttribute: .virus),55)
        XCTAssertEqual(DMCV1Engine.hitChance(power: 30,enemyPower: 30,attribute: .virus,enemyAttribute: .vaccine),45)
    }
    func testColdPausesAllGrowthAndCallGrace() throws {
        let content = try db(); var g = try game("agumon")
        g.pets[0].dmc!.hungerHearts = 0; g.pets[0].dmc!.hungerCall = noon; DMCV1Engine.sync(&g.pets[0])
        try GameEngine.perform(.freeze(true),state: &g,database: content,at: noon)
        let end = noon.addingTimeInterval(100*86400)
        try TimeEngine.advance(&g,to: end,database: content)
        XCTAssertEqual(g.pet.activeMinutes,0); XCTAssertEqual(g.pet.dmc!.stageMistakes,0)
        try GameEngine.perform(.freeze(false),state: &g,database: content,at: end)
        try TimeEngine.advance(&g,to: end.addingTimeInterval(9*60),database: content)
        XCTAssertEqual(g.pet.dmc!.stageMistakes,0)
        try TimeEngine.advance(&g,to: end.addingTimeInterval(10*60),database: content)
        XCTAssertEqual(g.pet.dmc!.stageMistakes,1)
    }
    func testSingleBackupFreezesOldPetAndRestoresEmptyHearts() throws {
        let content = try db(); var g = try game("agumon"); let original = g.pet.id
        g.pets[0].dmc!.stageTrainings = 32
        try DMCV1Engine.swapBackup(&g,at: noon)
        XCTAssertEqual(g.dmc!.backupPetID,original); XCTAssertTrue(g.pet.isEgg)
        XCTAssertEqual(g.pets[0].life,.frozen)
        let second = g.pet.id
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(608),database: content)
        XCTAssertEqual(g.pets[0].activeMinutes,0)
        try DMCV1Engine.swapBackup(&g,at: noon.addingTimeInterval(608))
        XCTAssertEqual(g.pet.id,original); XCTAssertEqual(g.dmc!.backupPetID,second)
        XCTAssertEqual(g.pet.dmc!.hungerHearts,0); XCTAssertEqual(g.pet.dmc!.strengthHearts,0)
        XCTAssertEqual(g.pet.dmc!.stageTrainings,32); XCTAssertEqual(g.pet.stats.weight,20)
        try content.validateSave(g)
    }
    func testSleepDisturbanceAndEightHoursRestoreDP() throws {
        let content = try db(); var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(secondsFromGMT: 0)!
        let night = c.date(from: DateComponents(year: 2026,month: 11,day: 27,hour: 0))!
        var g = try game("agumon"); g.lastTick = night; g.highWatermark = night; g.pets[0].stats.dp = 0
        g.pets[0].lightsOff = true
        try TimeEngine.advance(&g,to: night.addingTimeInterval(480*60),database: content)
        XCTAssertFalse(g.pet.sleeping)
        XCTAssertEqual(g.pet.stats.dp,20)
        var sleep = try game("agumon"); sleep.lastTick = night.addingTimeInterval(-60); sleep.highWatermark = sleep.lastTick
        sleep.pets[0].lightsOff = true; sleep.pets[0].stats.dp = 0
        try TimeEngine.advance(&sleep,to: night.addingTimeInterval(479*60),database: content)
        XCTAssertEqual(sleep.pet.stats.dp,20); XCTAssertTrue(sleep.pet.sleeping)
        try GameEngine.perform(.lights(false),state: &sleep,database: content,at: sleep.highWatermark)
        try DMCV1Engine.wake(&sleep,at: sleep.highWatermark)
        XCTAssertEqual(sleep.pet.dmc!.sleepDisturbances,1); XCTAssertFalse(sleep.pet.sleeping)
        XCTAssertEqual(sleep.pet.dmc!.stageMistakes,0)
    }
    func testTreatmentNeedsSpeciesDosesAndInjuryDeath() throws {
        let content = try db(); var g = try game("agumon")
        DMCV1Engine.injure(&g.pets[0],doses: 2,at: noon)
        try GameEngine.perform(.medicine,state: &g,database: content,at: noon)
        XCTAssertTrue(g.pet.stats.injured)
        try GameEngine.perform(.medicine,state: &g,database: content,at: noon)
        XCTAssertFalse(g.pet.stats.injured)
        DMCV1Engine.injure(&g.pets[0],doses: 2,at: noon)
        try TimeEngine.advance(&g,to: noon.addingTimeInterval(360*60),database: content)
        XCTAssertEqual(g.pet.life,.dead)
    }
    func testOriginalSaveRoundTripAndCorruptProfileRejected() throws {
        let content = try db(), store = SaveStore(directory: URL(fileURLWithPath: "/unused"),database: try db())
        var g = try game("agumon")
        try DMCV1Engine.beginTraining(&g,at: noon)
        _ = try DMCV1Engine.train(&g,choice: "B",database: content,at: noon)
        XCTAssertEqual(try store.decode(store.encode(g)).state,g)
        g.dmc!.clearedAreas = [2]
        XCTAssertThrowsError(try store.encode(g))
        g.dmc!.clearedAreas = []; g.pets[0].dmc = nil
        XCTAssertThrowsError(try store.encode(g))
    }
}
