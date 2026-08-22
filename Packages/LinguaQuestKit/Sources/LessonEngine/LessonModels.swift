import Foundation
import ContentModels

/// Что пользователь отправил в качестве ответа.
public enum AnswerInput: Equatable, Sendable {
    /// Выбор варианта (multiple_choice, listening).
    case choice(String)
    /// Ввод текстом (type_answer, fill_blank, speaking-транскрипт).
    case text(String)
    /// Одно сопоставление в match_pairs: какая пара и какой правый элемент выбран.
    case pairMatch(pairId: String, right: String)
    /// Собранное предложение (word_order).
    case tokens([String])
}

/// Вердикт по ответу.
public enum AnswerVerdict: Equatable, Sendable {
    case correct
    /// Верно с точностью до опечатки — сердце не снимаем.
    case almost
    case incorrect
}

/// Обратная связь для экрана после ответа.
public struct AnswerFeedback: Equatable, Sendable {
    public let verdict: AnswerVerdict
    /// Правильный ответ — показываем при ошибке и при опечатке.
    public let correctAnswer: String?
    public let explanation: String?
    /// Для match_pairs: задание ещё не закончено, ждём остальные пары.
    public let awaitingMorePairs: Bool
    public let heartsLeft: Int

    public init(
        verdict: AnswerVerdict,
        correctAnswer: String? = nil,
        explanation: String? = nil,
        awaitingMorePairs: Bool = false,
        heartsLeft: Int = 0
    ) {
        self.verdict = verdict
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.awaitingMorePairs = awaitingMorePairs
        self.heartsLeft = heartsLeft
    }
}

/// Зафиксированная ошибка — попадает в MistakeRecord и питает адаптивность Фазы 2.
public struct LessonMistake: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let exerciseId: String
    public let questionType: String
    public let prompt: String
    public let userAnswer: String
    public let correctAnswer: String
    public let errorCategory: String
    public let vocabularyIds: [String]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        exerciseId: String,
        questionType: String,
        prompt: String,
        userAnswer: String,
        correctAnswer: String,
        errorCategory: String,
        vocabularyIds: [String],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.questionType = questionType
        self.prompt = prompt
        self.userAnswer = userAnswer
        self.correctAnswer = correctAnswer
        self.errorCategory = errorCategory
        self.vocabularyIds = vocabularyIds
        self.timestamp = timestamp
    }
}

/// Как пользователь справился с конкретной словарной единицей — вход для SRS.
public struct VocabularyOutcome: Equatable, Sendable {
    public let itemId: String
    public let isCorrect: Bool
    public let responseTime: TimeInterval
    public let usedHint: Bool

    public init(itemId: String, isCorrect: Bool, responseTime: TimeInterval, usedHint: Bool) {
        self.itemId = itemId
        self.isCorrect = isCorrect
        self.responseTime = responseTime
        self.usedHint = usedHint
    }
}

/// Итог урока для экрана Lesson Complete и для записи прогресса.
public struct LessonSummary: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let lessonId: String
    public let skillKey: String
    public let totalExercises: Int
    public let correctFirstTry: Int
    public let scorePercent: Int
    public let xpEarned: Int
    public let coinsEarned: Int
    public let isPerfect: Bool
    /// Урок засчитан: набран проходной балл и сердца не кончились.
    public let isPassed: Bool
    public let ranOutOfHearts: Bool
    public let heartsLeft: Int
    public let duration: TimeInterval
    public let mistakes: [LessonMistake]
    public let vocabularyOutcomes: [VocabularyOutcome]
    public let completedAt: Date

    public init(
        id: UUID = UUID(),
        lessonId: String,
        skillKey: String,
        totalExercises: Int,
        correctFirstTry: Int,
        scorePercent: Int,
        xpEarned: Int,
        coinsEarned: Int,
        isPerfect: Bool,
        isPassed: Bool,
        ranOutOfHearts: Bool,
        heartsLeft: Int,
        duration: TimeInterval,
        mistakes: [LessonMistake],
        vocabularyOutcomes: [VocabularyOutcome],
        completedAt: Date = Date()
    ) {
        self.id = id
        self.lessonId = lessonId
        self.skillKey = skillKey
        self.totalExercises = totalExercises
        self.correctFirstTry = correctFirstTry
        self.scorePercent = scorePercent
        self.xpEarned = xpEarned
        self.coinsEarned = coinsEarned
        self.isPerfect = isPerfect
        self.isPassed = isPassed
        self.ranOutOfHearts = ranOutOfHearts
        self.heartsLeft = heartsLeft
        self.duration = duration
        self.mistakes = mistakes
        self.vocabularyOutcomes = vocabularyOutcomes
        self.completedAt = completedAt
    }
}

/// Фаза урока — по ней экран решает, что показывать.
public enum LessonPhase: Equatable, Sendable {
    /// Ждём ответа на текущее задание.
    case question
    /// Показан баннер с результатом ответа, ждём «Продолжить».
    case feedback(AnswerFeedback)
    /// Сердца кончились — урок прерван.
    case outOfHearts
    /// Урок завершён.
    case finished(LessonSummary)
}
