import Foundation

/// Числовые правила игровой экономики. В Фазе 2 часть значений переедет в Remote Config,
/// поэтому все обращения к константам идут через этот тип, а не разбросаны по коду.
public enum GameRules {

    // MARK: - Жизни

    /// Максимум сердец у free-пользователя.
    public static let maxHearts = 5
    /// Через сколько минут восстанавливается одно сердце.
    public static let heartRegenMinutes = 30
    /// Цена мгновенного восстановления всех сердец в гемах.
    public static let refillHeartsGemPrice = 45

    // MARK: - Награды

    /// Базовый XP за верный ответ (сверх xpReward урока).
    public static let xpPerCorrectAnswer = 2
    /// Бонус за урок без единой ошибки.
    public static let perfectLessonBonusXP = 10
    /// Монеты за завершённый урок.
    public static let coinsPerLesson = 5
    /// Дополнительные монеты за безошибочный урок.
    public static let perfectLessonBonusCoins = 3
    /// XP за каждую вспомненную карточку в сессии повторения.
    /// Меньше, чем за урок: повторение короче и легче, но должно двигать дневную цель.
    public static let xpPerReviewedCard = 1

    // MARK: - Mastery (короны навыка)

    /// Максимальный уровень освоения навыка.
    public static let maxMasteryLevel = 5
    /// Процент правильных ответов, начиная с которого урок считается пройденным.
    public static let passingScorePercent = 60

    // MARK: - Дневные цели

    public enum DailyGoal: Int, CaseIterable, Codable, Sendable {
        case casual = 10
        case regular = 20
        case serious = 50

        public var xp: Int { rawValue }

        public var titleKey: String {
            switch self {
            case .casual: return "goal.casual"
            case .regular: return "goal.regular"
            case .serious: return "goal.serious"
            }
        }
    }

    // MARK: - Streak

    /// Сколько заморозок streak можно держать одновременно.
    public static let maxStreakFreezes = 2
    /// Цена заморозки в монетах.
    public static let streakFreezeCoinPrice = 200
}
