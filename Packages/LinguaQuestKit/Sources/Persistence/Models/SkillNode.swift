import Foundation
import SwiftData

/// Прогресс пользователя по навыку. Сам навык (title, иконка, уроки) живёт в контенте —
/// здесь только то, что меняется в процессе игры.
@Model
public final class SkillNode {
    @Attribute(.unique) public var skillKey: String
    public var category: String
    public var cefrLevel: String
    public var isUnlocked: Bool
    /// 0...5 — короны освоения.
    public var masteryLevel: Int
    public var xpEarned: Int
    public var lastPracticedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \LessonProgress.skill)
    public var lessons: [LessonProgress]

    public init(
        skillKey: String,
        category: String,
        cefrLevel: String,
        isUnlocked: Bool = false,
        masteryLevel: Int = 0,
        xpEarned: Int = 0,
        lastPracticedAt: Date? = nil,
        lessons: [LessonProgress] = []
    ) {
        self.skillKey = skillKey
        self.category = category
        self.cefrLevel = cefrLevel
        self.isUnlocked = isUnlocked
        self.masteryLevel = masteryLevel
        self.xpEarned = xpEarned
        self.lastPracticedAt = lastPracticedAt
        self.lessons = lessons
    }
}

/// Статус урока в прогрессе пользователя.
public enum LessonStatus: String, Codable, Sendable {
    case locked
    case available
    case completed
}

/// Прогресс по конкретному уроку.
@Model
public final class LessonProgress {
    @Attribute(.unique) public var lessonId: String
    public var skillKey: String
    /// Строковое значение LessonStatus.
    public var status: String
    public var bestScore: Int
    public var attemptsCount: Int
    public var completedAt: Date?

    public var skill: SkillNode?

    @Relationship(deleteRule: .cascade, inverse: \MistakeRecord.lesson)
    public var mistakesLog: [MistakeRecord]

    public init(
        lessonId: String,
        skillKey: String,
        status: LessonStatus = .locked,
        bestScore: Int = 0,
        attemptsCount: Int = 0,
        completedAt: Date? = nil,
        skill: SkillNode? = nil,
        mistakesLog: [MistakeRecord] = []
    ) {
        self.lessonId = lessonId
        self.skillKey = skillKey
        self.status = status.rawValue
        self.bestScore = bestScore
        self.attemptsCount = attemptsCount
        self.completedAt = completedAt
        self.skill = skill
        self.mistakesLog = mistakesLog
    }

    public var lessonStatus: LessonStatus {
        get { LessonStatus(rawValue: status) ?? .locked }
        set { status = newValue.rawValue }
    }
}

/// Зафиксированная ошибка пользователя — основа адаптивности и разбора в конце урока.
@Model
public final class MistakeRecord {
    public var itemId: String
    public var questionType: String
    public var prompt: String
    public var userAnswer: String
    public var correctAnswer: String
    public var errorCategory: String
    public var timestamp: Date

    public var lesson: LessonProgress?

    public init(
        itemId: String,
        questionType: String,
        prompt: String,
        userAnswer: String,
        correctAnswer: String,
        errorCategory: String,
        timestamp: Date = Date(),
        lesson: LessonProgress? = nil
    ) {
        self.itemId = itemId
        self.questionType = questionType
        self.prompt = prompt
        self.userAnswer = userAnswer
        self.correctAnswer = correctAnswer
        self.errorCategory = errorCategory
        self.timestamp = timestamp
        self.lesson = lesson
    }
}
