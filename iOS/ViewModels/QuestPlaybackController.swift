import SwiftUI
import SpriteKit
import DigitalWorldCore

@MainActor
final class QuestPlaybackController: ObservableObject {
    let scene = QuestBattleScene(size: CGSize(width: 320,height: 200))
    @Published private(set) var battle = 0
    @Published private(set) var playerHits = 0
    @Published private(set) var enemyHits = 0
    @Published private(set) var phase = "准备"
    @Published private(set) var finished = false
    @Published private(set) var betweenBattles = false
    @Published private(set) var error: String?
    private var transition: Task<Void,Never>?
    private var active = false
    private var result: DMCQuestResult?
    private var database: ContentDatabase?
    private var mode: DisplayMode = .color
    private var reduced = false
    func start(_ result: DMCQuestResult,database: ContentDatabase?,mode: DisplayMode,reduceMotion: Bool) {
        guard !active else { return }
        self.result = result; self.database = database; self.mode = mode; reduced = reduceMotion
        active = true; showBattle()
    }
    func stop() { active = false; transition?.cancel(); scene.stop() }
    func skip() {
        guard active,!finished,!betweenBattles,let record = result?.records[battle] else { return }
        betweenBattles = true
        if let last = try? QuestReplay.rounds(for: record).last { playerHits = last.playerHits; enemyHits = last.opponentHits }
        scene.skip(won: record.won)
    }
    private func showBattle() {
        guard active,let result, result.records.indices.contains(battle),let database else { return }
        do {
            let record = result.records[battle]
            let rounds = try QuestReplay.rounds(for: record)
            let player = try database.species(result.playerSpeciesID), enemy = try database.species(record.opponent)
            playerHits = 0; enemyHits = 0; betweenBattles = false
            scene.onPhase = { [weak self] in self?.phase = $0 }
            scene.onHit = { [weak self] round in self?.playerHits = round.playerHits; self?.enemyHits = round.opponentHits }
            scene.onFinished = { [weak self] in self?.advance() }
            scene.play(player: player,opponent: enemy,record: record,rounds: rounds,mode: mode,
                       reduceMotion: reduced,boss: battle == result.area.opponents.count-1)
        } catch { self.error = error.localizedDescription; finished = true }
    }
    private func advance() {
        guard active,let result else { return }
        betweenBattles = true
        if battle+1 >= result.records.count { finished = true; return }
        transition?.cancel()
        transition = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled,let self,self.active else { return }
            self.battle += 1; self.showBattle()
        }
    }
}
