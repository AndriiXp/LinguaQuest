import Foundation
import UserNotifications

/// Виды напоминаний. Идентификаторы фиксированные: планировщик заменяет
/// прежнее уведомление, а не плодит дубли при каждом изменении настроек.
public enum ReminderKind: String, CaseIterable, Sendable {
    /// Ежедневное напоминание позаниматься.
    case dailyPractice = "reminder.daily"
    /// Предупреждение, что серия дней вот-вот сгорит.
    case streakAtRisk = "reminder.streak"
}

/// Текст напоминаний. Вынесен отдельно, чтобы формулировки правились
/// без раскопок в логике планирования, а варианты можно было чередовать.
public enum ReminderCopy {

    public static func daily(streak: Int) -> (title: String, body: String) {
        if streak >= 2 {
            return ("Серия: \(streak) \(dayWord(streak))",
                    "Пара минут занятий — и серия продолжится.")
        }
        return ("Время английского",
                "Один урок занимает пару минут. Начнём?")
    }

    public static func streakAtRisk(streak: Int) -> (title: String, body: String) {
        ("Серия \(streak) \(dayWord(streak)) под угрозой",
         "День почти закончился. Успейте выполнить дневную цель.")
    }

    static func dayWord(_ count: Int) -> String {
        let hundred = count % 100, ten = count % 10
        if (11...14).contains(hundred) { return "дней" }
        switch ten {
        case 1: return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
        }
    }
}

/// Планирует локальные напоминания. Сеть не нужна: всё считает система устройства.
@MainActor
public final class ReminderScheduler {

    /// За сколько часов до полуночи предупреждать о серии.
    public static let streakWarningHour = 20

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Запрашивает разрешение на уведомления. Возвращает false при отказе.
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            AppLog.ui.error("Не удалось запросить разрешение на уведомления: \(error.localizedDescription)")
            return false
        }
    }

    public func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Ставит ежедневное напоминание на указанное время.
    /// Повторный вызов заменяет прежнее — идентификатор один и тот же.
    public func scheduleDaily(at time: DateComponents, streak: Int) async {
        let copy = ReminderCopy.daily(streak: streak)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        var trigger = DateComponents()
        trigger.hour = time.hour
        trigger.minute = time.minute

        let request = UNNotificationRequest(
            identifier: ReminderKind.dailyPractice.rawValue,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )

        do {
            try await center.add(request)
            AppLog.ui.info("Ежедневное напоминание на \(time.hour ?? 0):\(time.minute ?? 0)")
        } catch {
            AppLog.ui.error("Не удалось запланировать напоминание: \(error.localizedDescription)")
        }
    }

    /// Предупреждение о сгорающей серии — только если серия есть
    /// и дневная цель ещё не выполнена.
    public func scheduleStreakWarning(streak: Int, goalReached: Bool) async {
        center.removePendingNotificationRequests(withIdentifiers: [ReminderKind.streakAtRisk.rawValue])
        guard streak > 0, !goalReached else { return }

        let copy = ReminderCopy.streakAtRisk(streak: streak)
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        var trigger = DateComponents()
        trigger.hour = Self.streakWarningHour
        trigger.minute = 30

        let request = UNNotificationRequest(
            identifier: ReminderKind.streakAtRisk.rawValue,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        try? await center.add(request)
    }

    /// Снимает все напоминания — при выключении настройки.
    public func cancelAll() {
        center.removePendingNotificationRequests(
            withIdentifiers: ReminderKind.allCases.map(\.rawValue)
        )
    }

    public func cancel(_ kind: ReminderKind) {
        center.removePendingNotificationRequests(withIdentifiers: [kind.rawValue])
    }

    /// Разбирает сохранённое время напоминания в компоненты часа и минуты.
    public static func components(from date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.hour, .minute], from: date)
    }

    /// Время по умолчанию — 19:00: вечер, когда день уже свободен,
    /// но до полуночи ещё есть запас выполнить цель.
    public static func defaultTime(calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    }
}
