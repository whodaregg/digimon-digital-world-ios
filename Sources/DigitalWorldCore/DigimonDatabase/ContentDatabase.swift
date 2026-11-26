import Foundation

public struct TileMap: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var rows: [String]
    public var enemies: [String]
    public var questTarget: Int
    public func tile(x: Int, y: Int) -> Character {
        guard y >= 0, y < rows.count, x >= 0, x < rows[y].count else { return "#" }
        return Array(rows[y])[x]
    }
}

public struct ContentDatabase: Codable, Sendable {
    public var version: Int
    public var species: [Species]
    public var devices: [DeviceRule]
    public var eggs: [Egg]
    public var foods: [Food]
    public var maps: [TileMap]
    public var dmcV1: DMCV1Rules?

    public static func bundled() throws -> Self {
        guard let url = Bundle.module.url(forResource: "database", withExtension: "json") else {
            throw GameError.invalidData("缺少 database.json")
        }
        var database = try load(Data(contentsOf: url))
        database.dmcV1 = try DMCV1Rules.bundled()
        try database.dmcV1?.validate(database: database)
        return database
    }
    public static func load(_ data: Data) throws -> Self {
        let content = try JSONDecoder().decode(Self.self, from: data)
        try content.validate()
        return content
    }
    public func species(_ id: String) throws -> Species {
        guard let value = species.first(where: { $0.id == id }) else { throw GameError.invalidData("未知角色：\(id)") }
        return value
    }
    public func device(_ id: String) throws -> DeviceRule {
        guard let value = devices.first(where: { $0.id == id }) else { throw GameError.invalidData("未知机型：\(id)") }
        return value
    }
    public func egg(_ id: String) throws -> Egg {
        guard let value = eggs.first(where: { $0.id == id }) else { throw GameError.invalidData("未知数码蛋：\(id)") }
        return value
    }
    public func validate() throws {
        func require(_ ok: Bool, _ message: String) throws { if !ok { throw GameError.invalidData(message) } }
        try require(version > 0 && !species.isEmpty && !devices.isEmpty, "内容版本或基本内容无效")
        for ids in [species.map(\.id), devices.map(\.id), eggs.map(\.id), foods.map(\.id), maps.map(\.id)] {
            try require(Set(ids).count == ids.count, "内容 ID 重复")
        }
        for s in species {
            try require((0...23).contains(s.sleepHour) && (0...23).contains(s.wakeHour), "睡眠时间无效")
            try require(s.lifespanMinutes > 0 && s.lifespanMinutes <= 60 * 24 * 90, "生命周期超出支持范围")
            try require(s.stats.hp > 0 && s.stats.attack > 0 && s.stats.defense > 0 && s.stats.speed > 0, "战斗数值无效")
            try require((0...100).contains(s.stats.critical), "暴击率无效")
            try require(Set(s.evolutions.map(\.id)).count == s.evolutions.count, "进化规则 ID 重复")
            for rule in s.evolutions {
                let target = try species(rule.target)
                try require(target.stage.order > s.stage.order, "普通进化必须提升阶段")
                try require(rule.stageMinutes > 0 && rule.minimumTraining >= 0 && rule.minimumBattles >= 0, "进化条件无效")
                try require((0...1).contains(rule.minimumWinRate), "胜率条件无效")
                try require(rule.minimumWeight <= rule.maximumWeight, "体重条件无效")
                try require(rule.provenance == "original-balance", "未经核实的规则不能声明为官方规则")
            }
        }
        for egg in eggs {
            let s = try species(egg.species)
            try require(s.stage == .baby1 && egg.hatchMinutes > 0, "数码蛋必须孵出幼年期 I")
        }
        for d in devices {
            try require(d.hungerEveryMinutes > 0 && d.wasteEveryMinutes > 0 && d.strengthEveryMinutes > 0 && d.careGraceMinutes > 0, "养成间隔无效")
            try require(!d.enabled || d.mode != .original || d.verifiedOriginal, "Original Mode 未完成说明书核验")
            try require(d.foods.allSatisfy { id in foods.contains { $0.id == id } }, "机型含未知食物")
            for id in d.eggs { _ = try egg(id) }
        }
        for map in maps {
            try require(!map.rows.isEmpty && (map.rows.first?.count ?? 0) > 2, "地图为空")
            try require(map.rows.allSatisfy { $0.count == map.rows[0].count }, "地图行宽不一致")
            try require(map.tile(x: 1, y: 1) != "#", "地图出生点不可通行")
            try require(map.questTarget > 0 && map.questTarget <= map.rows.joined().filter { $0 == "C" }.count, "任务目标不可达")
            for id in map.enemies { _ = try species(id) }
        }
    }
    public func validateSave(_ state: GameState) throws {
        guard state.schemaVersion == GameState.currentVersion else {
            throw GameError.futureSave(state.schemaVersion)
        }
        guard (-86_399...86_399).contains(state.clockOffsetSeconds ?? 0) else { throw GameError.invalidData("设备时钟偏移无效") }
        let ui = state.settings.presentation
        guard ui.volume.isFinite,(0...1).contains(ui.volume),ui.contrast.isFinite,(0.5...1.5).contains(ui.contrast),
              ui.brightness.isFinite,(0.3...1).contains(ui.brightness),["brown","gray","blue","white"].contains(ui.shell),
              (0...315_360_000).contains(state.sandboxOffsetSeconds ?? 0),
              state.playStyle == .sandbox || (state.sandboxOffsetSeconds ?? 0) == 0,
              state.playStyle != .sandbox || state.developerModifiedAt != nil else { throw GameError.invalidData("显示设置或Sandbox隔离标记无效") }
        let d = try device(state.deviceID)
        guard d.mode == state.mode, d.enabled, !state.pets.isEmpty,
              state.pets.count <= 32, state.pets.contains(where: { $0.id == state.activePetID }),
              Set(state.pets.map(\.id)).count == state.pets.count,
              TimeZone(identifier: state.homeTimeZone) != nil,
              state.lastTick <= state.highWatermark,
              state.highWatermark.timeIntervalSince1970.isFinite,
              state.lastTick.timeIntervalSince1970.isFinite,
              state.databaseVersion <= version else { throw GameError.invalidData("存档结构或内容版本不兼容") }
        for pet in state.pets {
            _ = try species(pet.speciesID); _ = try egg(pet.eggID)
            let s = pet.stats
            if let tuning = pet.developerTuning {
                guard state.developerModifiedAt != nil,
                      tuning.power.map({ (0...1_000_000).contains($0) }) ?? true,
                      tuning.maxDP.map({ (0...99).contains($0) }) ?? true else { throw GameError.invalidData("测试覆盖数值无效") }
                if let b = tuning.battleStats {
                    guard [b.hp,b.attack,b.defense,b.speed].allSatisfy({ (1...1_000_000).contains($0) }),
                          (0...100).contains(b.critical), (0...100).contains(b.stamina), (0...99).contains(b.dp) else {
                        throw GameError.invalidData("测试战斗数值无效")
                    }
                }
            }
            guard pet.activeMinutes >= 0, pet.stageMinutes >= 0, pet.awakeMinutes >= 0,
                  (0...100).contains(s.health), (0...100).contains(s.fullness),
                  (0...100).contains(s.energy), (0...100).contains(s.strength),
                  (0...100).contains(s.happiness), (0...100).contains(s.stamina),
                  (0...100).contains(s.bond), (0...100).contains(s.loyalty),
                  (1...999).contains(s.weight), (0...8).contains(s.waste),
                  s.wins >= 0, s.battles >= s.wins, s.mistakes >= 0,
                  s.training >= 0, s.trainingAttempts >= s.training else { throw GameError.invalidData("养成数据越界") }
            if state.deviceID == DMCV1Engine.deviceID {
                guard let c = pet.dmc, let rule = dmcV1?.roster[pet.speciesID], pet.eggID == "dmc-v1-egg",
                      (0...4).contains(c.hungerHearts), (0...4).contains(c.strengthHearts),
                      (0...7).contains(c.proteinOverdoses), (0...10).contains(c.meatBeyondFull),
                      (1...99).contains(s.weight), (0...(pet.developerTuning?.maxDP ?? rule.maxDP)).contains(s.dp),
                      c.eggStartedAt.timeIntervalSince1970.isFinite, c.eggStartedAt <= state.highWatermark,
                      [c.stageTrainings,c.stageMistakes,c.stageBattles,c.perfectBattleCount,c.megaBattleCount,
                       c.overfeeds,c.sleepDisturbances,c.proteinCount,c.stageInjuries,c.dosesRemaining,
                       c.hungerMinutes,c.strengthMinutes,c.wasteMinutes,c.emptyHungerMinutes,c.emptyStrengthMinutes,
                       c.injuredMinutes,c.sleepMinutes].allSatisfy({ $0 >= 0 && $0 < Int.max/1000 }),
                      [c.hungerCall,c.strengthCall,c.sleepCall,c.awakeUntil].compactMap({ $0 }).allSatisfy({ $0.timeIntervalSince1970.isFinite }),
                      s.fullness == c.hungerHearts*25, s.strength == c.strengthHearts*25 else {
                    throw GameError.invalidData("Ver.1 养成数据无效")
                }
            }
        }
        if let receipts = state.connectionReceipts {
            guard receipts.count <= 100_000,Set(receipts).count == receipts.count else { throw GameError.invalidData("通信收据重复或越界") }
        }
        if let records = state.lifecycles {
            guard records.count <= 10_000,Set(records.map(\.id)).count == records.count else { throw GameError.invalidData("生命周期记录越界或重复") }
            for record in records {
                _ = try species(record.finalSpeciesID); _ = try device(record.deviceID)
                guard record.startedAt.timeIntervalSince1970.isFinite,record.endedAt.timeIntervalSince1970.isFinite,
                      record.startedAt <= record.endedAt,record.endedAt <= state.highWatermark,
                      record.activeMinutes >= 0,record.battles >= record.wins,record.wins >= 0,
                      record.history.count <= 300,[nil,"death","reset"].contains(record.reason) else { throw GameError.invalidData("生命周期数据无效") }
                for id in record.forms { _ = try species(id) }
                for appearance in record.appearances {
                    _ = try species(appearance.speciesID)
                    guard appearance.date.timeIntervalSince1970.isFinite,appearance.date <= record.endedAt else { throw GameError.invalidData("获得日期无效") }
                }
            }
        }
        if let modified = state.developerModifiedAt {
            guard modified.timeIntervalSince1970.isFinite, modified <= state.highWatermark else { throw GameError.invalidData("测试记录时间无效") }
        }
        if state.deviceID == DMCV1Engine.deviceID {
            guard let c = state.dmc, (0..<10).contains(c.trainingCycle),
                  c.trainingChoices.count <= 5, c.trainingChoices.count == c.trainingHits.count,
                  c.trainingChoices.allSatisfy({ ["A","B"].contains($0) }),
                  c.clearedAreas == Set(1...8).intersection(c.clearedAreas),
                  c.clearedAreas.isEmpty || c.clearedAreas == Set(1...(c.clearedAreas.max() ?? 1)),
                  c.backgrounds.isSubset(of: ["grasslands","office","grid","dmc-logo","box-art","25th-anniversary"]),
                  c.backgrounds.contains(c.selectedBackground),
                  c.backupPetID == nil || state.pets.contains(where: { $0.id == c.backupPetID && $0.life == .frozen && $0.id != state.activePetID }),
                  !state.pets.contains(where: { $0.id != state.activePetID && $0.life == .alive }),
                  state.training == nil || (state.training?.petID == state.activePetID && c.trainingChoices.count < 5) else {
                throw GameError.invalidData("Ver.1 设备进度无效")
            }
        }
        guard state.inventory.values.allSatisfy({ $0 >= 0 && $0 <= 999999 }),
              maps.contains(where: { $0.id == state.adventure.mapID && $0.tile(x: state.adventure.x, y: state.adventure.y) != "#" }) else {
            throw GameError.invalidData("背包或地图数据无效")
        }
    }
}
