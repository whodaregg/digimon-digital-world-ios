import Foundation

public enum DeviceRegistry {
    public static func newGame(database: ContentDatabase, deviceID: String, eggID: String,
                               now: Date, timeZone: String = "UTC") throws -> GameState {
        let device = try database.device(deviceID)
        guard device.enabled else { throw GameError.unavailable(device.notes) }
        guard device.mode != .original || device.verifiedOriginal else {
            throw GameError.unavailable("该机型尚未完成实体机说明书核验")
        }
        guard device.eggs.contains(eggID), TimeZone(identifier: timeZone) != nil else {
            throw GameError.cannotAct("该机型不支持此数码蛋或时区无效")
        }
        let egg = try database.egg(eggID)
        guard egg.requiredRaised == 0 else { throw GameError.cannotAct("该数码蛋尚未解锁") }
        var pet = Pet(speciesID: egg.species, eggID: eggID)
        pet.record("egg", "数码蛋开始孵化", at: now)
        return GameState(databaseVersion: database.version, deviceID: deviceID, mode: device.mode,
                         timeZone: timeZone, now: now, pet: pet)
    }
}
