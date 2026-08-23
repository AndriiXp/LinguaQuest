import Foundation
import SwiftData

/// Активность за календарный день — источник данных для календаря занятий в профиле.
/// Хранится отдельной записью на день: так календарь строится одним запросом,
/// а не пересчётом всей истории уроков.
@Model
public final class DailyActivity {
    /// Начало дня в календаре пользователя.
    @Attribute(.unique) public var day: Date
    public var xpEarned: Int
    public var lessonsCompleted: Int

    public init(day: Date, xpEarned: Int = 0, lessonsCompleted: Int = 0) {
        self.day = day
        self.xpEarned = xpEarned
        self.lessonsCompleted = lessonsCompleted
    }
}
