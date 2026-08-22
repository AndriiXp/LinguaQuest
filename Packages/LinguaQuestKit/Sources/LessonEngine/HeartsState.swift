import Foundation
import Core

/// Система «жизней»: сердца тратятся на ошибки и восстанавливаются по времени.
/// Логика вынесена из UI, чтобы её можно было тестировать с подставным временем.
public struct HeartsState: Equatable, Sendable {
    /// Сколько сердец было в момент `lastSpentAt`.
    public private(set) var storedCount: Int
    /// Когда потратили сердце последний раз (точка отсчёта регенерации).
    public private(set) var lastSpentAt: Date?

    public init(count: Int = GameRules.maxHearts, lastSpentAt: Date? = nil) {
        self.storedCount = min(max(0, count), GameRules.maxHearts)
        self.lastSpentAt = lastSpentAt
    }

    /// Актуальное количество сердец с учётом восстановившихся за прошедшее время.
    public func current(at date: Date = Date()) -> Int {
        guard storedCount < GameRules.maxHearts, let lastSpentAt else {
            return storedCount
        }
        let minutes = date.timeIntervalSince(lastSpentAt) / 60
        guard minutes > 0 else { return storedCount }
        let regenerated = Int(minutes) / GameRules.heartRegenMinutes
        return min(GameRules.maxHearts, storedCount + regenerated)
    }

    /// Сколько секунд до восстановления следующего сердца. nil — если сердца полные.
    public func secondsUntilNextHeart(at date: Date = Date()) -> TimeInterval? {
        guard current(at: date) < GameRules.maxHearts, let lastSpentAt else { return nil }
        let period = TimeInterval(GameRules.heartRegenMinutes * 60)
        let elapsed = date.timeIntervalSince(lastSpentAt)
        guard elapsed >= 0 else { return period }
        return period - elapsed.truncatingRemainder(dividingBy: period)
    }

    /// Тратит одно сердце. Возвращает обновлённое состояние.
    public func spending(at date: Date = Date()) -> HeartsState {
        let actual = current(at: date)
        guard actual > 0 else {
            return HeartsState(count: 0, lastSpentAt: lastSpentAt ?? date)
        }
        return HeartsState(count: actual - 1, lastSpentAt: date)
    }

    /// Полное восстановление (покупка за гемы, подписка, новый день).
    public func refilled() -> HeartsState {
        HeartsState(count: GameRules.maxHearts, lastSpentAt: nil)
    }

    public func isEmpty(at date: Date = Date()) -> Bool {
        current(at: date) == 0
    }
}
