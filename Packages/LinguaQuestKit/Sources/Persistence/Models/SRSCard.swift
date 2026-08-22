import Foundation
import SwiftData
import SRSEngine

/// Карточка интервального повтора. Расчёт расписания делает SM2Scheduler,
/// модель только хранит состояние.
@Model
public final class SRSCard {
    @Attribute(.unique) public var itemId: String
    public var word: String
    public var translation: String
    public var easeFactor: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var nextReviewDate: Date
    public var lastReviewedAt: Date?
    public var lapses: Int
    public var createdAt: Date

    public init(
        itemId: String,
        word: String,
        translation: String,
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        repetitions: Int = 0,
        nextReviewDate: Date = Date(),
        lastReviewedAt: Date? = nil,
        lapses: Int = 0,
        createdAt: Date = Date()
    ) {
        self.itemId = itemId
        self.word = word
        self.translation = translation
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
        self.lapses = lapses
        self.createdAt = createdAt
    }

    /// Снимок состояния для алгоритма.
    public var state: SRSCardState {
        SRSCardState(
            easeFactor: easeFactor,
            intervalDays: intervalDays,
            repetitions: repetitions,
            lapses: lapses,
            nextReviewDate: nextReviewDate,
            lastReviewedAt: lastReviewedAt
        )
    }

    /// Применяет результат расчёта обратно в модель.
    public func apply(_ state: SRSCardState) {
        easeFactor = state.easeFactor
        intervalDays = state.intervalDays
        repetitions = state.repetitions
        lapses = state.lapses
        nextReviewDate = state.nextReviewDate
        lastReviewedAt = state.lastReviewedAt
    }
}

/// Достижение игрока.
@Model
public final class Achievement {
    @Attribute(.unique) public var achievementKey: String
    public var unlockedAt: Date?
    /// Текущий прогресс для накопительных достижений.
    public var progress: Int
    /// Сколько нужно для разблокировки.
    public var target: Int

    public init(achievementKey: String, unlockedAt: Date? = nil, progress: Int = 0, target: Int = 1) {
        self.achievementKey = achievementKey
        self.unlockedAt = unlockedAt
        self.progress = progress
        self.target = target
    }

    public var isUnlocked: Bool { unlockedAt != nil }
}
