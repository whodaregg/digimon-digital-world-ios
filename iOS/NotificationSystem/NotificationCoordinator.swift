import UserNotifications
import DigitalWorldCore

@MainActor
final class NotificationCoordinator {
    private let center = UNUserNotificationCenter.current()
    func requestAuthorization() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
    func cancel() { center.removePendingNotificationRequests(withIdentifiers: ["care.hatch", "care.hunger", "care.waste"]) }
    func schedule(game: GameState, database: ContentDatabase) {
        cancel()
        guard game.settings.notifications, game.pet.life == .alive,
              let device = try? database.device(game.deviceID) else { return }
        let now = Date()
        var candidates: [(String, String, Int)] = []
        if let care = game.pet.dmc, let rule = database.dmcV1?.roster[game.pet.speciesID] {
            if game.pet.isEgg {
                candidates.append(("hatch","数码蛋即将孵化",max(1,Int(ceil(care.eggStartedAt.addingTimeInterval(8).timeIntervalSince(now))))))
            } else if !game.pet.sleeping {
                candidates.append(("hunger","回来查看伙伴的饱食与力量吧",max(1,rule.heartLossMinutes-care.hungerMinutes)*60))
                if game.pet.stats.waste > 0 { candidates.append(("waste","伙伴的环境需要清理",300)) }
            }
        } else if game.pet.isEgg, let egg = try? database.egg(game.pet.eggID) {
            candidates.append(("hatch", "数码蛋即将孵化", max(1, egg.hatchMinutes - game.pet.stageMinutes)*60))
        } else if !game.pet.sleeping {
            // A conservative call reminder, not a promise of an exact hunger event.
            let next = max(1, device.hungerEveryMinutes - game.pet.awakeMinutes % device.hungerEveryMinutes)
            candidates.append(("hunger", "回来查看伙伴的饱食度吧", next*60))
            if game.pet.stats.waste > 0 { candidates.append(("waste", "伙伴的环境需要清理", 300)) }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: game.homeTimeZone) ?? .current
        for (key, title, seconds) in candidates {
            let date = now.addingTimeInterval(Double(seconds))
            let hour = calendar.component(.hour, from: date)
            if TimeEngine.isSleepHour(hour, sleep: game.settings.quietStart, wake: game.settings.quietEnd) { continue }
            let content = UNMutableNotificationContent()
            content.title = "Digital World"; content.body = title
            if game.settings.sound { content.sound = .default }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(seconds), repeats: false)
            center.add(UNNotificationRequest(identifier: "care.\(key)", content: content, trigger: trigger))
        }
    }
}
