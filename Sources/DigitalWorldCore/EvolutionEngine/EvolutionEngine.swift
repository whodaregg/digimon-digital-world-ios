import Foundation

public enum EvolutionEngine {
    public static func eligible(_ rule: EvolutionRule, pet: Pet, inventory: [String: Int]) -> Bool {
        let s = pet.stats
        return pet.life == .alive && !pet.isEgg && !s.sick && !s.injured &&
            pet.stageMinutes >= rule.stageMinutes && s.training >= rule.minimumTraining &&
            s.battles >= rule.minimumBattles && s.winRate >= rule.minimumWinRate &&
            s.mistakes >= rule.minimumMistakes && s.mistakes <= (rule.maximumMistakes ?? Int.max) &&
            s.health >= rule.minimumHealth && (rule.minimumWeight...rule.maximumWeight).contains(s.weight) &&
            s.bond >= rule.minimumBond && (rule.requiredItem.map { inventory[$0, default: 0] > 0 } ?? true)
    }
    public static func candidate(pet: Pet, database: ContentDatabase, inventory: [String: Int]) throws -> EvolutionRule? {
        try database.species(pet.speciesID).evolutions.sorted {
            $0.priority == $1.priority ? $0.id < $1.id : $0.priority > $1.priority
        }.first { eligible($0, pet: pet, inventory: inventory) }
    }
}
