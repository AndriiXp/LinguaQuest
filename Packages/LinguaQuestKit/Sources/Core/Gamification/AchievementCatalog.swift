import Foundation

/// По какому счётчику растёт достижение.
/// Значение — порог, при достижении которого награда открывается.
public enum AchievementGoal: Equatable, Sendable {
    /// Серия дней подряд.
    case streak(days: Int)
    /// Пройдено уроков всего.
    case lessonsCompleted(count: Int)
    /// Уроков пройдено без единой ошибки.
    case perfectLessons(count: Int)
    /// Накоплено опыта.
    case totalXP(amount: Int)
    /// Слов взято в работу (создано карточек повторения).
    case wordsLearned(count: Int)
    /// Получено корон освоения.
    case crowns(count: Int)
    /// Навыков открыто.
    case skillsUnlocked(count: Int)

    public var target: Int {
        switch self {
        case .streak(let v), .lessonsCompleted(let v), .perfectLessons(let v),
             .totalXP(let v), .wordsLearned(let v), .crowns(let v), .skillsUnlocked(let v):
            return v
        }
    }
}

/// Описание достижения. Хранится в коде: это статические правила игры,
/// а в базе лежит только прогресс игрока по ним.
public struct AchievementDefinition: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String
    public let goal: AchievementGoal
    /// Цвет значка берётся из палитры по этому ключу.
    public let tintKey: String

    public init(
        id: String,
        title: String,
        detail: String,
        symbolName: String,
        goal: AchievementGoal,
        tintKey: String
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.goal = goal
        self.tintKey = tintKey
    }

    public var target: Int { goal.target }
}

/// Снимок игровых счётчиков — по нему считается прогресс всех достижений.
public struct AchievementStats: Equatable, Sendable {
    public var streak: Int
    public var lessonsCompleted: Int
    public var perfectLessons: Int
    public var totalXP: Int
    public var wordsLearned: Int
    public var crowns: Int
    public var skillsUnlocked: Int

    public init(
        streak: Int = 0,
        lessonsCompleted: Int = 0,
        perfectLessons: Int = 0,
        totalXP: Int = 0,
        wordsLearned: Int = 0,
        crowns: Int = 0,
        skillsUnlocked: Int = 0
    ) {
        self.streak = streak
        self.lessonsCompleted = lessonsCompleted
        self.perfectLessons = perfectLessons
        self.totalXP = totalXP
        self.wordsLearned = wordsLearned
        self.crowns = crowns
        self.skillsUnlocked = skillsUnlocked
    }

    /// Текущее значение счётчика, к которому привязано достижение.
    public func value(for goal: AchievementGoal) -> Int {
        switch goal {
        case .streak: return streak
        case .lessonsCompleted: return lessonsCompleted
        case .perfectLessons: return perfectLessons
        case .totalXP: return totalXP
        case .wordsLearned: return wordsLearned
        case .crowns: return crowns
        case .skillsUnlocked: return skillsUnlocked
        }
    }
}

/// Каталог достижений Фазы 1. Пороги подобраны так, чтобы первые награды
/// приходили в первый же день, а последние оставались целью на месяцы.
public enum AchievementCatalog {

    public static let all: [AchievementDefinition] = [
        // Первые шаги
        AchievementDefinition(
            id: "first_lesson", title: "Первый шаг",
            detail: "Пройдите первый урок",
            symbolName: "figure.walk", goal: .lessonsCompleted(count: 1), tintKey: "primary"
        ),
        AchievementDefinition(
            id: "ten_lessons", title: "Разогрев",
            detail: "Пройдите 10 уроков",
            symbolName: "book.fill", goal: .lessonsCompleted(count: 10), tintKey: "primary"
        ),
        AchievementDefinition(
            id: "fifty_lessons", title: "Постоянство",
            detail: "Пройдите 50 уроков",
            symbolName: "books.vertical.fill", goal: .lessonsCompleted(count: 50), tintKey: "primary"
        ),

        // Качество
        AchievementDefinition(
            id: "first_perfect", title: "Без единой ошибки",
            detail: "Пройдите урок идеально",
            symbolName: "star.fill", goal: .perfectLessons(count: 1), tintKey: "xp"
        ),
        AchievementDefinition(
            id: "ten_perfect", title: "Точность",
            detail: "10 идеальных уроков",
            symbolName: "target", goal: .perfectLessons(count: 10), tintKey: "xp"
        ),

        // Серия
        AchievementDefinition(
            id: "streak_3", title: "Три дня подряд",
            detail: "Серия из 3 дней",
            symbolName: "flame", goal: .streak(days: 3), tintKey: "streak"
        ),
        AchievementDefinition(
            id: "streak_7", title: "Неделя",
            detail: "Серия из 7 дней",
            symbolName: "flame.fill", goal: .streak(days: 7), tintKey: "streak"
        ),
        AchievementDefinition(
            id: "streak_30", title: "Месяц без пропусков",
            detail: "Серия из 30 дней",
            symbolName: "calendar", goal: .streak(days: 30), tintKey: "streak"
        ),

        // Опыт и лексика
        AchievementDefinition(
            id: "xp_500", title: "Пятьсот",
            detail: "Наберите 500 XP",
            symbolName: "bolt.fill", goal: .totalXP(amount: 500), tintKey: "xp"
        ),
        AchievementDefinition(
            id: "xp_2000", title: "Две тысячи",
            detail: "Наберите 2000 XP",
            symbolName: "bolt.circle.fill", goal: .totalXP(amount: 2000), tintKey: "xp"
        ),
        AchievementDefinition(
            id: "words_25", title: "Словарный запас",
            detail: "Возьмите в работу 25 слов",
            symbolName: "text.book.closed.fill", goal: .wordsLearned(count: 25), tintKey: "gem"
        ),
        AchievementDefinition(
            id: "words_100", title: "Сотня слов",
            detail: "Возьмите в работу 100 слов",
            symbolName: "character.book.closed.fill", goal: .wordsLearned(count: 100), tintKey: "gem"
        ),

        // Дерево навыков
        AchievementDefinition(
            id: "first_crown", title: "Первая корона",
            detail: "Освойте навык полностью",
            symbolName: "crown.fill", goal: .crowns(count: 1), tintKey: "coin"
        ),
        AchievementDefinition(
            id: "five_crowns", title: "Коллекционер корон",
            detail: "Получите 5 корон",
            symbolName: "crown", goal: .crowns(count: 5), tintKey: "coin"
        ),
        AchievementDefinition(
            id: "all_skills", title: "Первооткрыватель",
            detail: "Откройте 3 навыка",
            symbolName: "map.fill", goal: .skillsUnlocked(count: 3), tintKey: "success"
        )
    ]

    public static func definition(id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }

    /// Прогресс по достижению: сколько набрано и открыто ли оно.
    public static func progress(for definition: AchievementDefinition, stats: AchievementStats) -> (value: Int, isUnlocked: Bool) {
        let value = min(stats.value(for: definition.goal), definition.target)
        return (value, value >= definition.target)
    }

    /// Достижения, которые открылись при переходе от `before` к `after`.
    /// Возвращает только те, что раньше не были открыты — чтобы не показывать награду дважды.
    public static func newlyUnlocked(before: AchievementStats, after: AchievementStats) -> [AchievementDefinition] {
        all.filter { definition in
            let was = progress(for: definition, stats: before).isUnlocked
            let now = progress(for: definition, stats: after).isUnlocked
            return !was && now
        }
    }
}
