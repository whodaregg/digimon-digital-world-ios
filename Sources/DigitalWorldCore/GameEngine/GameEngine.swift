import Foundation

public enum CareAction: Sendable {
    case feed(String), clean, medicine, lights(Bool), rest(Bool), freeze(Bool), rebirth(String), selectPet(UUID)
}

public enum GameEngine {
    public static func perform(_ action: CareAction, state: inout GameState,
                               database: ContentDatabase, at now: Date) throws {
        try TimeEngine.advance(&state, to: now, database: database)
        guard now >= state.highWatermark else { throw GameError.cannotAct("设备时间早于已保存时间，请恢复正确时间") }
        if DeviceRegistry.isColor(state.deviceID) {
            try DMCV1Engine.perform(action,state: &state,database: database,at: now)
            return
        }
        // Transaction: a rejected command never partly consumes items or changes a pet.
        var result = state
        let index = result.activeIndex
        let device = try database.device(result.deviceID)
        switch action {
        case .selectPet(let id):
            guard result.pets.contains(where: { $0.id == id }) else { throw GameError.cannotAct("找不到伙伴") }
            result.activePetID = id; result.training = nil
        case .rebirth(let eggID):
            guard result.pet.life == .dead else { throw GameError.cannotAct("伙伴仍在成长，请继续照顾它") }
            guard !result.pets.contains(where: { $0.life != .dead }) else {
                throw GameError.cannotAct("已有伙伴正在成长或冷冻中，请先切换回当前伙伴")
            }
            let egg = try database.egg(eggID)
            guard device.eggs.contains(eggID), result.dex.values.filter({ $0 == .raised }).count >= egg.requiredRaised else {
                throw GameError.cannotAct("数码蛋尚未解锁")
            }
            try LifecycleManager.makeRoom(&result)
            var newPet = Pet(speciesID: egg.species, eggID: eggID)
            newPet.record("egg", "继承图鉴，重新开始", at: now)
            result.pets.append(newPet); result.activePetID = newPet.id; result.training = nil
            result.adventure = AdventureState()
        case .freeze(let frozen):
            guard device.freezeSupported, result.pet.life != .dead else { throw GameError.cannotAct("当前状态不支持冷冻") }
            result.pets[index].life = frozen ? .frozen : .alive; result.training = nil
            result.pets[index].record("freeze", frozen ? "成长暂停" : "恢复成长", at: now)
        default:
            guard result.pet.life == .alive, !result.pet.isEgg else { throw GameError.cannotAct("需要已孵化且正在成长的伙伴") }
            guard result.training == nil else { throw GameError.cannotAct("请先完成或取消训练") }
            switch action {
            case .feed(let id):
                guard !result.pet.sleeping, device.foods.contains(id), let food = database.foods.first(where: { $0.id == id }) else {
                    throw GameError.cannotAct("当前不能喂食")
                }
                // Staple meat/protein are unlimited; other foods are adventure rewards.
                if !["meat", "protein"].contains(id) {
                    guard result.inventory[id, default: 0] > 0 else { throw GameError.cannotAct("背包中没有这种食物") }
                    result.inventory[id, default: 0] -= 1
                }
                let overfed = result.pet.stats.fullness + food.fullness > 100
                result.pets[index].stats.fullness += food.fullness
                result.pets[index].stats.strength += food.strength
                result.pets[index].stats.happiness += food.happiness
                result.pets[index].stats.energy += food.energy
                result.pets[index].stats.health += food.health - (overfed ? 3 : 0)
                result.pets[index].stats.weight += food.weight
                result.pets[index].stats.meals += 1
                if !overfed { result.pets[index].stats.bond += 1 }
                if result.pets[index].stats.meals % 4 == 0 { result.pets[index].stats.waste += 1 }
                result.pets[index].record("feed", "\(food.name)\(overfed ? " · 过量喂食" : "")", at: now)
            case .clean:
                guard result.pet.stats.waste > 0 else { throw GameError.cannotAct("环境已经很干净") }
                result.pets[index].stats.waste = 0; result.pets[index].dirtyMinutes = 0
                result.pets[index].stats.happiness += 3
                result.pets[index].record("clean", "清理完成", at: now)
            case .medicine:
                guard result.pet.stats.sick || result.pet.stats.injured else { throw GameError.cannotAct("伙伴很健康，无需用药") }
                result.pets[index].stats.sick = false; result.pets[index].stats.injured = false
                result.pets[index].stats.health += 25; result.pets[index].stats.happiness -= 2
                result.pets[index].dirtyMinutes = 0
                result.pets[index].record("medicine", "治疗完成，请保持环境清洁", at: now)
            case .lights(let off):
                result.pets[index].lightsOff = off
            case .rest(let rest):
                guard device.manualRestSupported else { throw GameError.cannotAct("该机型不支持手动休息") }
                result.pets[index].manualRest = rest
                let species = try database.species(result.pet.speciesID)
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: result.homeTimeZone)!
                result.pets[index].sleeping = rest || TimeEngine.isSleepHour(calendar.component(.hour, from: now), sleep: species.sleepHour, wake: species.wakeHour)
                if rest { result.pets[index].lightsOff = true }
            default: break
            }
            result.pets[index].stats.clamp()
        }
        state = result
    }
}
