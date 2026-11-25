import Foundation

public struct SeededRandom: RandomNumberGenerator, Sendable {
    public var state: UInt64
    public init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    public mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
    public mutating func number(_ upper: Int) -> Int { Int(next() % UInt64(max(1, upper))) }
}

public enum BattleEngine {
    public static func multiplier(attacker: Attribute, defender: Attribute) -> Double {
        if attacker == .free || defender == .free || attacker == .unknown || defender == .unknown { return 1 }
        switch (attacker, defender) {
        case (.vaccine, .virus), (.virus, .data), (.data, .vaccine): return 1.25
        case (.virus, .vaccine), (.data, .virus), (.vaccine, .data): return 0.8
        default: return 1
        }
    }
    /// Original offline PVE rules. Not an emulation of a physical device battle protocol.
    public static func fight(_ state: inout GameState, opponentID: String,
                             database: ContentDatabase, at now: Date) throws -> BattleRecord {
        guard state.deviceID != DMCV1Engine.deviceID else { throw GameError.cannotAct("Ver.1 请进入 Quest 顺序闯关") }
        let index = state.activeIndex
        let p = state.pet
        var player = try database.species(p.speciesID)
        if let stats = p.developerTuning?.battleStats { player.stats = stats }
        let enemy = try database.species(opponentID)
        guard p.life == .alive, !p.isEgg, !p.sleeping, !p.stats.sick, !p.stats.injured,
              p.stats.energy >= 15, p.stats.stamina >= 15, p.stats.health >= 30,
              player.stage.order >= Stage.rookie.order, enemy.stage.order >= Stage.rookie.order else {
            throw GameError.cannotAct("对战需要成长至成长期，保持清醒健康，能量与体力不少于 15")
        }
        guard state.training == nil else { throw GameError.cannotAct("请先结束训练") }
        var rng = SeededRandom(seed: state.rng)
        var hp = max(1, player.stats.hp * p.stats.health / 100)
        var enemyHP = enemy.stats.hp
        var log: [String] = []
        var turns = 0
        let playerFirst = player.stats.speed >= enemy.stats.speed
        func hit(_ attacker: Species, _ defender: Species, training: Int, special: Bool,
                 rng: inout SeededRandom, defenderHP: inout Int) -> String {
            if rng.number(100) >= max(65, min(98, 90 + attacker.stats.speed - defender.stats.speed)) {
                return "\(attacker.name) 的攻击被闪避"
            }
            let critical = rng.number(100) < attacker.stats.critical
            let base = max(2, attacker.stats.attack + min(20, training) - defender.stats.defense / 2)
            let factor = multiplier(attacker: attacker.attribute, defender: defender.attribute)
            let damage = max(1, Int(Double(base) * factor * (special ? 1.5 : 1) * (critical ? 1.5 : 1)) + rng.number(5))
            defenderHP = max(0, defenderHP - damage)
            return "\(attacker.name) · \(special ? attacker.specialMove : "攻击")\(critical ? " 暴击" : "") −\(damage) HP"
        }
        while hp > 0 && enemyHP > 0 && turns < 40 {
            turns += 1
            for playerTurn in playerFirst ? [true, false] : [false, true] {
                if hp <= 0 || enemyHP <= 0 { break }
                if playerTurn {
                    let special = turns % 3 == 0 && state.pets[index].stats.dp > 0
                    if special { state.pets[index].stats.dp -= 1 }
                    log.append(hit(player, enemy, training: p.stats.training + p.stats.strength / 10,
                                   special: special, rng: &rng, defenderHP: &enemyHP))
                } else {
                    log.append(hit(enemy, player, training: 0, special: turns % 3 == 0, rng: &rng, defenderHP: &hp))
                }
            }
        }
        let won = enemyHP == 0 && hp > 0
        state.rng = rng.state
        state.pets[index].stats.energy -= 15; state.pets[index].stats.stamina -= 15
        state.pets[index].stats.battles += 1
        if won {
            state.pets[index].stats.wins += 1; state.pets[index].stats.happiness += 5
            state.pets[index].stats.bond += 1; state.inventory["recovery", default: 0] += 1
        } else {
            state.pets[index].stats.health -= 10; state.pets[index].stats.injured = true
            state.pets[index].stats.injuries += 1; state.pets[index].stats.happiness -= 5
        }
        state.pets[index].stats.clamp()
        state.pets[index].record("battle", "\(won ? "胜利" : "败北") · \(enemy.name)", at: now)
        state.dex[enemy.id] = max(state.dex[enemy.id] ?? .encountered, .encountered)
        let record = BattleRecord(id: UUID(), date: now, opponent: enemy.id, won: won,
                                  turns: turns, hpRemaining: hp, log: log)
        state.battles.append(record)
        if state.battles.count > 100 { state.battles.removeFirst() }
        return record
    }
}
