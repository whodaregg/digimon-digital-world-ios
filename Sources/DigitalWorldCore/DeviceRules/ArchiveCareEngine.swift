import Foundation

/// User-supplied characters share the existing general care and battle rules.
public enum ArchiveCareEngine {
    public static let deviceID = "character-archive"

    public static func adopt(_ speciesID: String, database: ContentDatabase,
                             at now: Date, timeZone: String = "UTC") throws -> GameState {
        let species = try database.species(speciesID)
        guard species.devices.contains(deviceID) else {
            throw GameError.cannotAct("请选择上传图集中的数码兽")
        }
        var game = try DeviceRegistry.newGame(database: database, deviceID: deviceID,
                                              eggID: "founder", now: now, timeZone: timeZone)
        game.pets[0].speciesID = speciesID
        game.pets[0].isEgg = false
        game.pets[0].evolutionHistory = [speciesID]
        game.pets[0].appearances = [SpeciesAppearance(speciesID, at: now)]
        game.pets[0].record("adopt", "开始养成 · \(species.name)", at: now)
        game.dex[speciesID] = .raised
        try database.validateSave(game)
        return game
    }
}
