import Foundation

public struct ConnectionFighter: Codable, Equatable, Sendable {
    public var protocolVersion = 1
    public var petID: UUID
    public var nonce: UUID
    public var deviceID: String
    public var speciesID: String
    public var strength: Int
    public var traited: Bool
    public var sandbox: Bool
    public var powerOverride: Int?
}
public struct ConnectionBattleResult: Equatable, Sendable {
    public var id: UUID
    public var playerWon: Bool
    public var opponentID: String
    public var hits: [BattleSide]
    public var injured: Bool
}
public enum ConnectionEngine {
    public static func fighter(for state: GameState,database: ContentDatabase,nonce: UUID = UUID()) throws -> ConnectionFighter {
        guard state.deviceID == DMCV1Engine.deviceID,state.pet.life == .alive,!state.pet.isEgg,!state.pet.sleeping,
              !state.pet.stats.injured,state.pet.stats.dp > 0,state.training == nil,
              try database.species(state.pet.speciesID).stage.order >= Stage.rookie.order else { throw GameError.cannotAct("通信需要清醒、无伤、DP至少1的成长期以上伙伴") }
        guard state.playStyle == .sandbox || state.developerModifiedAt == nil else { throw GameError.cannotAct("修改过的档案只能在Sandbox参与测试对战") }
        return .init(petID: state.pet.id,nonce: nonce,deviceID: state.deviceID,speciesID: state.pet.speciesID,
                     strength: state.pet.dmc?.strengthHearts ?? 0,traited: state.pet.dmc?.traited ?? false,sandbox: state.playStyle == .sandbox,powerOverride: state.playStyle == .sandbox ? state.pet.developerTuning?.power : nil)
    }
    public static func validate(_ fighter: ConnectionFighter,database: ContentDatabase) throws {
        guard fighter.protocolVersion == 1,fighter.deviceID == DMCV1Engine.deviceID,(0...4).contains(fighter.strength),
              try database.species(fighter.speciesID).stage.order >= Stage.rookie.order,
              database.dmcV1?.roster[fighter.speciesID] != nil,
              fighter.sandbox || fighter.powerOverride == nil,
              fighter.powerOverride.map({ (0...1_000_000).contains($0) }) ?? true else { throw GameError.invalidData("对方的通信协议、机型或角色不受支持") }
    }
    public static func resolve(player: ConnectionFighter,opponent: ConnectionFighter,database: ContentDatabase) throws -> ConnectionBattleResult {
        try validate(player,database: database); try validate(opponent,database: database)
        guard player.petID != opponent.petID,player.sandbox == opponent.sandbox else { throw GameError.cannotAct("Sandbox只允许与Sandbox连接，且双方须为不同伙伴") }
        let sorted = [player,opponent].sorted { $0.nonce.uuidString < $1.nonce.uuidString }
        guard sorted[0].nonce != sorted[1].nonce else { throw GameError.invalidData("通信随机标识重复") }
        let identity = sorted.map { "\($0.petID.uuidString):\($0.nonce.uuidString):\($0.speciesID)" }.joined(separator: "|")
        let seed = UInt64(SaveStore.checksum(Data(identity.utf8)),radix: 16) ?? 1
        var rng = SeededRandom(seed: seed)
        func power(_ fighter: ConnectionFighter) throws -> Int {
            let s = try database.species(fighter.speciesID),base = try database.dmcV1!.species(fighter.speciesID).power
            let bonus = s.stage == .rookie ? 5 : s.stage == .champion ? 8 : s.stage == .ultimate ? 15 : 25
            return (fighter.powerOverride ?? base)+(fighter.strength == 4 ? bonus : 0)+(fighter.traited ? bonus : 0)
        }
        let chance = try DMCV1Engine.hitChance(power: power(sorted[0]),enemyPower: power(sorted[1]),
                    attribute: database.species(sorted[0].speciesID).attribute,enemyAttribute: database.species(sorted[1].speciesID).attribute)
        let firstWon = rng.number(100) < chance, playerFirst = player.nonce == sorted[0].nonce
        let won = playerFirst ? firstWon : !firstWon
        let id = JournalEvent(date: Date(timeIntervalSince1970: 0),kind: "connection",message: identity).id
        // COLOR communication: first three exchanges always hit; the fourth decides.
        let hits: [BattleSide] = [.player,.opponent,.player,.opponent,.player,.opponent,won ? .player : .opponent]
        let injury = rng.number(100) < (won ? 20 : 10)
        return .init(id: id,playerWon: won,opponentID: opponent.speciesID,hits: hits,injured: injury)
    }
    @discardableResult public static func apply(_ result: ConnectionBattleResult,player: ConnectionFighter,opponent: ConnectionFighter,
                                                state: inout GameState,database: ContentDatabase,at date: Date) throws -> BattleRecord {
        let expected = try resolve(player: player,opponent: opponent,database: database)
        guard expected == result,!(state.connectionReceipts ?? []).contains(result.id) else { throw GameError.cannotAct("通信战果不一致或已经保存，不能重复领奖") }
        let current = try fighter(for: state,database: database,nonce: player.nonce)
        guard current == player else { throw GameError.cannotAct("伙伴状态已变化，请重新连接") }
        var next = state
        guard (next.connectionReceipts?.count ?? 0) < 100_000 else { throw GameError.cannotAct("通信记录容量已满，请先导出完整档案") }
        let i = next.activeIndex, rule = try database.dmcV1!.species(player.speciesID),stage = try database.species(player.speciesID).stage
        next.pets[i].stats.dp -= 1; next.pets[i].stats.weight = max(rule.minimumWeight,next.pet.stats.weight-6)
        next.pets[i].stats.battles += 1; next.pets[i].dmc!.stageBattles += 1
        if result.playerWon { next.pets[i].stats.wins += 1 }
        if stage == .rookie || stage == .champion { next.pets[i].dmc!.perfectBattleCount += 1 }
        if stage == .ultimate { next.pets[i].dmc!.megaBattleCount += 1 }
        if result.injured { DMCV1Engine.injure(&next.pets[i],doses: rule.healDoses,at: date) }
        next.dex[opponent.speciesID] = max(next.dex[opponent.speciesID] ?? .encountered,.encountered)
        let record = BattleRecord(id: result.id,date: date,opponent: opponent.speciesID,won: result.playerWon,turns: 4,hpRemaining: 0,
                                 log: ["通信对战 · 前三轮双方命中","第四轮 · \(result.playerWon ? "胜利" : "败北")"],hitSequence: result.hits)
        next.battles.append(record); if next.battles.count > 100 { next.battles.removeFirst(next.battles.count-100) }
        next.connectionReceipts = (next.connectionReceipts ?? []) + [result.id]
        next.pets[i].record("connection",result.playerWon ? "通信对战胜利" : "通信对战败北",at: date)
        if next.pet.dmc?.stageInjuries ?? 0 >= 15 { DMCV1Engine.die(&next,at: date); LifecycleManager.capture(&next) }
        try database.validateSave(next); state = next; return record
    }
}
