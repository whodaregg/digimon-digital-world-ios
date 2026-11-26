import Foundation

public struct AdventureResult: Sendable {
    public var message: String
    public var encounter: String?
    public var questCompleted: Bool
}

public enum AdventureEngine {
    public static func move(_ state: inout GameState, dx: Int, dy: Int,
                            database: ContentDatabase, at now: Date) throws -> AdventureResult {
        guard !DeviceRegistry.isColor(state.deviceID) else { throw GameError.cannotAct("Ver.1 通过 Quest 顺序闯关") }
        guard abs(dx) + abs(dy) == 1 else { throw GameError.cannotAct("每次移动一格") }
        guard state.pet.life == .alive, !state.pet.isEgg, !state.pet.sleeping,
              !state.pet.stats.sick, !state.pet.stats.injured, state.pet.stats.energy > 0,
              try database.species(state.pet.speciesID).stage.order >= Stage.rookie.order else {
            throw GameError.cannotAct("冒险需要清醒、健康、拥有能量的成长期伙伴")
        }
        guard state.training == nil else { throw GameError.cannotAct("请先结束训练") }
        guard let map = database.maps.first(where: { $0.id == state.adventure.mapID }) else { throw GameError.invalidData("地图不存在") }
        let x = state.adventure.x + dx, y = state.adventure.y + dy
        let tile = map.tile(x: x, y: y)
        guard tile != "#" && tile != "~" else { throw GameError.cannotAct("前方无法通行") }
        state.adventure.x = x; state.adventure.y = y; state.adventure.steps += 1
        state.pets[state.activeIndex].stats.energy -= 1
        var message = "探索信号花园"
        let key = "\(map.id):\(x):\(y)"
        var completed = false
        if tile == "C" && !state.adventure.collected.contains(key) {
            state.adventure.collected.insert(key); state.inventory["fruit", default: 0] += 2
            state.inventory["recovery", default: 0] += 1
            state.inventory["vegetable", default: 0] += 1
            state.inventory["energy", default: 0] += 1
            message = "找到数据碎片 · 水果 +2，蔬菜、能量饮料和恢复食物各 +1"
            if state.adventure.collected.count >= map.questTarget && !state.adventure.questComplete {
                state.adventure.questComplete = true; state.inventory["evolution-chip", default: 0] += 1
                state.inventory["special", default: 0] += 1; completed = true
                message = "任务完成 · 获得进化芯片和特别食物"
                state.pets[state.activeIndex].record("quest", message, at: now)
            }
        }
        var encounter: String?
        if tile == "." && state.adventure.steps % 7 == 0 && !map.enemies.isEmpty {
            var rng = SeededRandom(seed: state.rng)
            let id = map.enemies[rng.number(map.enemies.count)]
            state.rng = rng.state
            state.dex[id] = max(state.dex[id] ?? .encountered, .encountered)
            encounter = id; message = "发现野生伙伴 · \((try database.species(id)).name)"
        }
        return AdventureResult(message: message, encounter: encounter, questCompleted: completed)
    }
}
