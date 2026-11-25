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
        if game.pet.isEgg, let egg = try? database.egg(game.pet.eggID) {
            candidates.append(("hatch", "数码蛋即将孵化", max(1, egg.hatchMinutes - game.pet.stageMinutes)))
        } else if !game.pet.sleeping {
            // A conservative call reminder, not a promise of an exact hunger event.
            let next = max(1, device.hungerEveryMinutes - game.pet.awakeMinutes % device.hungerEveryMinutes)
            candidates.append(("hunger", "回来查看伙伴的饱食度吧", next))
            if game.pet.stats.waste > 0 { candidates.append(("waste", "伙伴的环境需要清理", 5)) }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: game.homeTimeZone) ?? .current
        for (key, title, minutes) in candidates {
            let date = now.addingTimeInterval(Double(minutes*60))
            let hour = calendar.component(.hour, from: date)
            if TimeEngine.isSleepHour(hour, sleep: game.settings.quietStart, wake: game.settings.quietEnd) { continue }
            let content = UNMutableNotificationContent()
            content.title = "Digital World"; content.body = title
            if game.settings.sound { content.sound = .default }
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes*60), repeats: false)
            center.add(UNNotificationRequest(identifier: "care.\(key)", content: content, trigger: trigger))
        }
    }
}
