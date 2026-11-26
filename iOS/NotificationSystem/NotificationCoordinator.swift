import UserNotifications
import DigitalWorldCore

@MainActor
final class NotificationCoordinator {
    private let center = UNUserNotificationCenter.current()
    func requestAuthorization() async throws -> Bool { try await center.requestAuthorization(options: [.alert,.sound,.badge]) }
    func cancel() { center.removeAllPendingNotificationRequests() }
    func schedule(worlds: [(String,GameState)],database: ContentDatabase) {
        cancel(); let now = Date()
        var requests: [(Date,UNNotificationRequest)] = []
        for (id,game) in worlds where game.settings.notifications && game.playStyle != .sandbox {
            guard let reminders = try? AttentionForecast.reminders(for: game,database: database,from: now) else { continue }
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: game.homeTimeZone) ?? .current
            for reminder in reminders {
                let hour = calendar.component(.hour,from: reminder.date)
                if TimeEngine.isSleepHour(hour,sleep: game.settings.quietStart,wake: game.settings.quietEnd) { continue }
                let content = UNMutableNotificationContent()
                content.title = "Digital World"; content.body = reminder.message
                if game.settings.sound { content.sound = .default }
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1,reminder.date.timeIntervalSince(now)),repeats: false)
                requests.append((reminder.date,UNNotificationRequest(identifier: "care.\(id).\(reminder.kind)",content: content,trigger: trigger)))
            }
        }
        for (_,request) in requests.sorted(by: { $0.0 < $1.0 }).prefix(60) { center.add(request) }
    }
}
