import Foundation
import SwiftData

/// Профиль игрока. В Фазе 1 он один и создаётся как гостевой,
/// в Фазе 2 к нему привяжется Firebase-аккаунт.
@Model
public final class UserProfile {
    /// Уникальный ключ — нужен для дедупликации при будущей синхронизации.
    @Attribute(.unique) public var id: UUID
    public var displayName: String
    /// Строковое значение CEFRLevel: "A1", "A2"...
    public var currentCEFR: String
    public var xpTotal: Int
    public var level: Int
    public var coins: Int
    public var gems: Int

    // Streak
    public var streakCount: Int
    public var streakLastActive: Date?
    public var streakFreezes: Int

    // Сердца (счётчик + точка отсчёта регенерации)
    public var heartsCount: Int
    public var heartsLastSpentAt: Date?

    public var dailyGoalXP: Int
    /// XP, набранный сегодня — сбрасывается при смене календарного дня.
    public var todayXP: Int
    public var todayXPDate: Date

    /// Накопительные счётчики для достижений. Отдельно от статусов уроков,
    /// потому что при получении короны уроки открываются заново и их статусы сбрасываются.
    public var lessonsCompletedTotal: Int
    public var perfectLessonsTotal: Int

    public var selectedAvatarId: String
    public var createdAt: Date

    @Relationship(deleteRule: .cascade)
    public var settings: UserSettings?

    @Relationship(deleteRule: .cascade, inverse: \UnlockedAvatar.profile)
    public var unlockedAvatars: [UnlockedAvatar]

    public init(
        id: UUID = UUID(),
        displayName: String = "Гость",
        currentCEFR: String = "A1",
        xpTotal: Int = 0,
        level: Int = 1,
        coins: Int = 0,
        gems: Int = 0,
        streakCount: Int = 0,
        streakLastActive: Date? = nil,
        streakFreezes: Int = 0,
        heartsCount: Int = 5,
        heartsLastSpentAt: Date? = nil,
        dailyGoalXP: Int = 20,
        todayXP: Int = 0,
        todayXPDate: Date = Date(),
        lessonsCompletedTotal: Int = 0,
        perfectLessonsTotal: Int = 0,
        selectedAvatarId: String = "fox",
        createdAt: Date = Date(),
        settings: UserSettings? = nil,
        unlockedAvatars: [UnlockedAvatar] = []
    ) {
        self.id = id
        self.displayName = displayName
        self.currentCEFR = currentCEFR
        self.xpTotal = xpTotal
        self.level = level
        self.coins = coins
        self.gems = gems
        self.streakCount = streakCount
        self.streakLastActive = streakLastActive
        self.streakFreezes = streakFreezes
        self.heartsCount = heartsCount
        self.heartsLastSpentAt = heartsLastSpentAt
        self.dailyGoalXP = dailyGoalXP
        self.todayXP = todayXP
        self.todayXPDate = todayXPDate
        self.lessonsCompletedTotal = lessonsCompletedTotal
        self.perfectLessonsTotal = perfectLessonsTotal
        self.selectedAvatarId = selectedAvatarId
        self.createdAt = createdAt
        self.settings = settings
        self.unlockedAvatars = unlockedAvatars
    }
}

/// Пользовательские настройки.
@Model
public final class UserSettings {
    @Attribute(.unique) public var id: UUID
    public var soundEnabled: Bool
    public var hapticsEnabled: Bool
    public var notificationsEnabled: Bool
    public var dailyReminderEnabled: Bool
    public var reminderTime: Date?
    /// "ru" | "en"
    public var interfaceLanguage: String

    public init(
        id: UUID = UUID(),
        soundEnabled: Bool = true,
        hapticsEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        dailyReminderEnabled: Bool = false,
        reminderTime: Date? = nil,
        interfaceLanguage: String = "ru"
    ) {
        self.id = id
        self.soundEnabled = soundEnabled
        self.hapticsEnabled = hapticsEnabled
        self.notificationsEnabled = notificationsEnabled
        self.dailyReminderEnabled = dailyReminderEnabled
        self.reminderTime = reminderTime
        self.interfaceLanguage = interfaceLanguage
    }
}

/// Разблокированный аватар. Каталог аватаров статичен и лежит в коде (AvatarCatalog),
/// в базе хранится только факт владения.
@Model
public final class UnlockedAvatar {
    public var avatarId: String
    public var unlockedAt: Date
    public var profile: UserProfile?

    public init(avatarId: String, unlockedAt: Date = Date(), profile: UserProfile? = nil) {
        self.avatarId = avatarId
        self.unlockedAt = unlockedAt
        self.profile = profile
    }
}
