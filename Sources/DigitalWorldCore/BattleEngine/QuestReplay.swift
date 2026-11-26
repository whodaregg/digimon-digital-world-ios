import Foundation

public enum BattleSide: String, Codable, Sendable { case player, opponent }

public struct BattleReplayRound: Equatable, Sendable {
    public let number: Int
    public let winner: BattleSide
    public let playerHits: Int
    public let opponentHits: Int
    public init(number: Int,winner: BattleSide,playerHits: Int,opponentHits: Int) {
        self.number = number; self.winner = winner; self.playerHits = playerHits; self.opponentHits = opponentHits
    }
}

/// Pure presentation data. Replaying a saved result never consumes RNG or DP.
public enum QuestReplay {
    public static func rounds(for record: BattleRecord) throws -> [BattleReplayRound] {
        let sequence: [BattleSide]
        if let saved = record.hitSequence { sequence = saved }
        else {
            sequence = try record.log.map { line in
                if line.hasPrefix("攻击命中") { return .player }
                if line.hasPrefix("受到攻击") { return .opponent }
                throw GameError.invalidData("这不是Quest命中记录")
            }
        }
        guard sequence.count == record.turns, (3...5).contains(sequence.count) else {
            throw GameError.invalidData("Quest回合数量错误")
        }
        var hits = 0, received = 0, result: [BattleReplayRound] = []
        for (index,side) in sequence.enumerated() {
            guard hits < 3 && received < 3 else { throw GameError.invalidData("战斗结束后仍有多余回合") }
            if side == .player { hits += 1 } else { received += 1 }
            result.append(BattleReplayRound(number: index+1,winner: side,playerHits: hits,opponentHits: received))
        }
        guard (hits == 3 || received == 3), record.won == (hits == 3) else {
            throw GameError.invalidData("命中记录与胜负不一致")
        }
        return result
    }
}
