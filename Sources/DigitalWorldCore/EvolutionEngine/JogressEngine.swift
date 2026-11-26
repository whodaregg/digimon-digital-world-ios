import Foundation

/// COLOR communication Jogress evolves each device's own partner; it does not consume a local backup.
public enum JogressEngine {
    @discardableResult
    public static func applyAfterConnection(_ state: inout GameState,opponent: ConnectionFighter,database: ContentDatabase,at date: Date) throws -> Bool {
        let pair = (state.deviceID,state.pet.speciesID,opponent.deviceID,opponent.speciesID)
        let compatible = (pair.0 == "dmc-ver1" && pair.1 == "blitzgreymon" && pair.2 == "dmc-ver2" && pair.3 == "cresgarurumon") ||
            (pair.0 == "dmc-ver2" && pair.1 == "cresgarurumon" && pair.2 == "dmc-ver1" && pair.3 == "blitzgreymon")
        guard compatible,state.pet.life == .alive else { return false }
        let rules = try DMCV1Engine.rules(database,deviceID: state.deviceID)
        DMCV1Engine.evolve(&state,to: "omegamon-alter-s",rules: rules,at: date)
        state.pets[state.activeIndex].record("jogress","通信联展 · 奥米加兽 Alter-S",at: date)
        return true
    }
}
