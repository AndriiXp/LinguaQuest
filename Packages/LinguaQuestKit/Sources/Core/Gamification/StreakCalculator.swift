import Foundation

/// Состояние серии дней (streak) — чистое значение, чтобы логику можно было тестировать
/// без SwiftData и без системного времени.
public struct StreakState: Equatable, Sendable {
    public var count: Int
    public var freezes: Int
    public var lastActiveDay: Date?

    public init(count: Int = 0, freezes: Int = 0, lastActiveDay: Date? = nil) {
        self.count = count
        self.freezes = freezes
        self.lastActiveDay = lastActiveDay
    }
}

/// Что произошло со streak при пересчёте — нужно, чтобы UI показал нужную анимацию.
public enum StreakEvent: Equatable, Sendable {
    /// Ничего не изменилось (тот же день или цель ещё не выполнена).
    case unchanged
    /// Серия продолжена, новое значение.
    case extended(to: Int)
    /// Серия спасена заморозками, потрачено `used` штук.
    case savedByFreeze(used: Int)
    /// Серия сброшена: пропущено `missedDays` дней и заморозок не хватило.
    case reset(missedDays: Int)
}

/// Правила серии: продление при выполнении дневной цели, автосписание заморозок при пропуске.
public enum StreakCalculator {

    /// Пересчитывает streak на момент `now` — вызывается при запуске приложения.
    /// Здесь серия только теряется или спасается заморозкой; растёт она в `registerGoalReached`.
    public static func refresh(
        _ state: StreakState,
        now: Date,
        calendar: Calendar = .current
    ) -> (state: StreakState, event: StreakEvent) {
        guard let lastActive = state.lastActiveDay, state.count > 0 else {
            return (state, .unchanged)
        }

        let gap = dayGap(from: lastActive, to: now, calendar: calendar)
        // 0 — сегодня, 1 — вчера: серия ещё жива, сегодняшний день просто не закрыт.
        guard gap > 1 else { return (state, .unchanged) }

        let missedDays = gap - 1
        var updated = state

        if state.freezes >= missedDays {
            updated.freezes -= missedDays
            // Заморозка закрывает пропуски, поэтому «последняя активность» подтягивается ко вчера.
            updated.lastActiveDay = calendar.date(
                byAdding: .day,
                value: -1,
                to: calendar.startOfDay(for: now)
            )
            return (updated, .savedByFreeze(used: missedDays))
        }

        // Серия сгорает, но купленные заморозки остаются у игрока —
        // они оплачены и пригодятся для следующей серии.
        updated.count = 0
        updated.lastActiveDay = nil
        return (updated, .reset(missedDays: missedDays))
    }

    /// Вызывается в момент, когда пользователь набрал дневную цель XP.
    public static func registerGoalReached(
        _ state: StreakState,
        now: Date,
        calendar: Calendar = .current
    ) -> (state: StreakState, event: StreakEvent) {
        let today = calendar.startOfDay(for: now)
        var updated = state

        if let lastActive = state.lastActiveDay {
            let gap = dayGap(from: lastActive, to: now, calendar: calendar)
            switch gap {
            case 0:
                // Цель за сегодня уже засчитана — повторно не начисляем.
                return (state, .unchanged)
            case 1:
                updated.count += 1
            default:
                // Пропуск не был обработан refresh — начинаем серию заново.
                updated.count = 1
            }
        } else {
            updated.count = max(1, state.count == 0 ? 1 : state.count + 1)
        }

        updated.lastActiveDay = today
        return (updated, .extended(to: updated.count))
    }

    /// Разница в календарных днях между двумя датами (>= 0).
    static func dayGap(from: Date, to: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}
