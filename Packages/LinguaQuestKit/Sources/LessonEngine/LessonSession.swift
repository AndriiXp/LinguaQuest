import Foundation
import Observation
import Core
import ContentModels

/// Обёртка над генератором случайных чисел.
/// `shuffle(using:)` принимает `inout T: RandomNumberGenerator`, а экзистенциал
/// `any RandomNumberGenerator` в inout-параметр передать нельзя — отсюда стирание типа.
public struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var base: any RandomNumberGenerator

    public init(_ base: any RandomNumberGenerator) {
        self.base = base
    }

    public mutating func next() -> UInt64 {
        base.next()
    }
}

/// Стейт-машина одного прохождения урока.
///
/// Не знает ни про SwiftUI, ни про SwiftData: получает контент, принимает ответы,
/// отдаёт фазу и итог. Благодаря этому весь игровой цикл покрывается юнит-тестами.
@Observable
public final class LessonSession {

    // MARK: - Вход

    public let lesson: LessonContent
    public let skillKey: String

    /// Сколько раз задание может вернуться в конец очереди после ошибки,
    /// прежде чем движок перестанет его повторять (защита от бесконечного урока).
    private let maxRequeuesPerExercise = 2

    // MARK: - Состояние

    public private(set) var phase: LessonPhase = .question
    public private(set) var hearts: HeartsState
    public private(set) var mistakes: [LessonMistake] = []
    /// Пары, уже сопоставленные в текущем match_pairs.
    public private(set) var matchedPairIds: Set<String> = []
    /// Была ли использована подсказка в текущем задании.
    public private(set) var hintRevealed = false

    private var queue: [Exercise]
    private var position = 0
    private var firstTryCorrect: [String: Bool] = [:]
    /// Задания, закрытые в этом проходе: либо отвечены верно, либо исчерпали лимит повторов.
    private var closedExerciseIds: Set<String> = []
    private var requeueCount: [String: Int] = [:]
    private var vocabularyOutcomes: [VocabularyOutcome] = []
    private var hadWrongPairInCurrentExercise = false
    /// Пары, на которых уже ошиблись. Сердце снимается один раз за пару,
    /// иначе серия быстрых тапов по неверному варианту опустошила бы жизни.
    private var failedPairIds: Set<String> = []
    private var exerciseStartedAt: Date
    private let startedAt: Date
    private let now: () -> Date

    // MARK: - Инициализация

    /// - Parameters:
    ///   - lesson: контент урока
    ///   - skillKey: навык, которому принадлежит урок
    ///   - hearts: текущее состояние сердец пользователя
    ///   - shuffle: перемешивать ли задания (по умолчанию — порядок из контента)
    ///   - randomGenerator: генератор для перемешивания, подменяется в тестах
    ///   - now: источник времени, подменяется в тестах
    public init(
        lesson: LessonContent,
        skillKey: String,
        hearts: HeartsState = HeartsState(),
        shuffle: Bool = false,
        randomGenerator: AnyRandomNumberGenerator? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.lesson = lesson
        self.skillKey = skillKey
        self.hearts = hearts
        self.now = now

        var exercises = lesson.exercises
        if shuffle {
            if var generator = randomGenerator {
                exercises.shuffle(using: &generator)
            } else {
                exercises.shuffle()
            }
        }
        self.queue = exercises

        let start = now()
        self.startedAt = start
        self.exerciseStartedAt = start

        if exercises.isEmpty {
            self.phase = .finished(Self.emptySummary(lessonId: lesson.lessonId, skillKey: skillKey, at: start))
        } else if hearts.isEmpty(at: start) {
            self.phase = .outOfHearts
        }
    }

    // MARK: - Доступ для UI

    public var currentExercise: Exercise? {
        guard position < queue.count else { return nil }
        return queue[position]
    }

    /// Позиция в очереди. Нужна UI как часть идентичности вью: одно и то же
    /// задание может встретиться дважды, и его экран должен начаться с чистого листа.
    public var currentPosition: Int { position }

    /// Сколько заданий урока уже закрыто — для прогресс-бара.
    public var completedCount: Int {
        closedExerciseIds.count
    }

    public var totalCount: Int {
        lesson.exercises.count
    }

    /// Прогресс урока 0...1.
    public var progress: Double {
        guard totalCount > 0 else { return 1 }
        return min(1, Double(completedCount) / Double(totalCount))
    }

    public var heartsLeft: Int {
        hearts.current(at: now())
    }

    public var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    // MARK: - Действия

    /// Показать подсказку: не снимает сердце, но снижает оценку для SRS.
    public func revealHint() {
        hintRevealed = true
    }

    /// Принимает ответ и обновляет фазу. Возвращает ту же обратную связь, что попадает в фазу.
    @discardableResult
    public func submit(_ input: AnswerInput) -> AnswerFeedback {
        guard case .question = phase, let exercise = currentExercise else {
            return AnswerFeedback(verdict: .incorrect, heartsLeft: heartsLeft)
        }

        if case .pairMatch(let pairId, let right) = input {
            return submitPair(exercise: exercise, pairId: pairId, right: right)
        }

        let userText = plainText(from: input)
        let match = evaluate(exercise: exercise, input: input)

        switch match {
        case .exact:
            return registerSuccess(exercise: exercise, verdict: .correct, correctAnswer: nil)
        case .typo(let correct):
            return registerSuccess(exercise: exercise, verdict: .almost, correctAnswer: correct)
        case .wrong:
            return registerFailure(exercise: exercise, userAnswer: userText)
        }
    }

    /// Переход к следующему заданию после показа обратной связи.
    public func advance() {
        guard case .feedback = phase else { return }

        if let exercise = currentExercise, !closedExerciseIds.contains(exercise.id) {
            // Задание не решено — возвращаем его в конец очереди, но не бесконечно.
            let count = requeueCount[exercise.id, default: 0]
            if count < maxRequeuesPerExercise {
                requeueCount[exercise.id] = count + 1
                queue.append(exercise)
            } else {
                // Лимит повторов исчерпан: закрываем задание как несделанное.
                firstTryCorrect[exercise.id] = false
                closedExerciseIds.insert(exercise.id)
            }
        }

        position += 1
        matchedPairIds = []
        failedPairIds = []
        hadWrongPairInCurrentExercise = false
        hintRevealed = false
        exerciseStartedAt = now()

        if position >= queue.count {
            finish(ranOutOfHearts: false)
        } else {
            phase = .question
        }
    }

    /// Прерывание урока, когда кончились сердца.
    public func abandon() {
        finish(ranOutOfHearts: true)
    }

    /// Восстановить сердца (покупка/подписка) и продолжить урок с того же задания.
    public func refillHearts() {
        hearts = hearts.refilled()
        guard case .outOfHearts = phase else { return }
        if position < queue.count {
            phase = .question
        } else {
            finish(ranOutOfHearts: false)
        }
    }

    // MARK: - Внутреннее

    private func evaluate(exercise: Exercise, input: AnswerInput) -> AnswerMatch {
        switch input {
        case .choice(let value):
            // Выбор из готовых вариантов — опечаток быть не может.
            return AnswerValidator.match(input: value, against: exercise.allCorrectAnswers, allowTypos: false)
        case .text(let value):
            return AnswerValidator.match(input: value, against: exercise.allCorrectAnswers, allowTypos: true)
        case .tokens(let tokens):
            return AnswerValidator.match(
                input: tokens.joined(separator: " "),
                against: exercise.allCorrectAnswers,
                allowTypos: false
            )
        case .pairMatch:
            return .wrong // обрабатывается отдельно
        }
    }

    private func plainText(from input: AnswerInput) -> String {
        switch input {
        case .choice(let value): return value
        case .text(let value): return value
        case .tokens(let tokens): return tokens.joined(separator: " ")
        case .pairMatch(_, let right): return right
        }
    }

    private func submitPair(exercise: Exercise, pairId: String, right: String) -> AnswerFeedback {
        guard let pairs = exercise.pairs, let pair = pairs.first(where: { $0.id == pairId }) else {
            return AnswerFeedback(verdict: .incorrect, awaitingMorePairs: true, heartsLeft: heartsLeft)
        }

        let isCorrect = AnswerValidator.normalize(pair.right) == AnswerValidator.normalize(right)

        guard isCorrect else {
            hadWrongPairInCurrentExercise = true
            if failedPairIds.insert(pairId).inserted {
                spendHeart()
                recordMistake(exercise: exercise, userAnswer: right, correctAnswer: pair.right)
            }

            let feedback = AnswerFeedback(
                verdict: .incorrect,
                correctAnswer: pair.right,
                explanation: exercise.explanation,
                awaitingMorePairs: true,
                heartsLeft: heartsLeft
            )
            if hearts.isEmpty(at: now()) {
                phase = .outOfHearts
            }
            return feedback
        }

        matchedPairIds.insert(pairId)
        let allMatched = matchedPairIds.count == pairs.count

        if allMatched {
            let cleanRun = !hadWrongPairInCurrentExercise
            if firstTryCorrect[exercise.id] == nil {
                firstTryCorrect[exercise.id] = cleanRun
            }
            closedExerciseIds.insert(exercise.id)
            recordVocabularyOutcomes(exercise: exercise, isCorrect: cleanRun)
            let feedback = AnswerFeedback(
                verdict: cleanRun ? .correct : .almost,
                correctAnswer: nil,
                explanation: exercise.explanation,
                awaitingMorePairs: false,
                heartsLeft: heartsLeft
            )
            phase = .feedback(feedback)
            return feedback
        }

        return AnswerFeedback(verdict: .correct, awaitingMorePairs: true, heartsLeft: heartsLeft)
    }

    private func registerSuccess(exercise: Exercise, verdict: AnswerVerdict, correctAnswer: String?) -> AnswerFeedback {
        // Первая попытка засчитывается, только если задание ещё не было провалено.
        if firstTryCorrect[exercise.id] == nil {
            firstTryCorrect[exercise.id] = true
        }
        closedExerciseIds.insert(exercise.id)
        recordVocabularyOutcomes(exercise: exercise, isCorrect: true)

        let feedback = AnswerFeedback(
            verdict: verdict,
            correctAnswer: correctAnswer,
            explanation: exercise.explanation,
            heartsLeft: heartsLeft
        )
        phase = .feedback(feedback)
        return feedback
    }

    private func registerFailure(exercise: Exercise, userAnswer: String) -> AnswerFeedback {
        firstTryCorrect[exercise.id] = false
        spendHeart()
        recordMistake(exercise: exercise, userAnswer: userAnswer, correctAnswer: exercise.correctAnswer ?? "")
        recordVocabularyOutcomes(exercise: exercise, isCorrect: false)

        let feedback = AnswerFeedback(
            verdict: .incorrect,
            correctAnswer: exercise.correctAnswer,
            explanation: exercise.explanation,
            heartsLeft: heartsLeft
        )
        phase = hearts.isEmpty(at: now()) ? .outOfHearts : .feedback(feedback)
        return feedback
    }

    private func spendHeart() {
        hearts = hearts.spending(at: now())
    }

    private func recordMistake(exercise: Exercise, userAnswer: String, correctAnswer: String) {
        mistakes.append(
            LessonMistake(
                exerciseId: exercise.id,
                questionType: exercise.type.rawValue,
                prompt: exercise.prompt,
                userAnswer: userAnswer,
                correctAnswer: correctAnswer,
                errorCategory: exercise.errorCategory ?? "unspecified",
                vocabularyIds: exercise.vocabularyIds ?? [],
                timestamp: now()
            )
        )
    }

    private func recordVocabularyOutcomes(exercise: Exercise, isCorrect: Bool) {
        guard let ids = exercise.vocabularyIds, !ids.isEmpty else { return }
        let elapsed = now().timeIntervalSince(exerciseStartedAt)
        for id in ids {
            vocabularyOutcomes.append(
                VocabularyOutcome(
                    itemId: id,
                    isCorrect: isCorrect,
                    responseTime: elapsed,
                    usedHint: hintRevealed
                )
            )
        }
    }

    private func finish(ranOutOfHearts: Bool) {
        let total = totalCount
        let correct = firstTryCorrect.values.filter { $0 }.count
        let score = total > 0 ? Int((Double(correct) / Double(total) * 100).rounded()) : 0
        let isPerfect = mistakes.isEmpty && correct == total && total > 0
        let isPassed = !ranOutOfHearts && score >= GameRules.passingScorePercent

        var xp = 0
        var coins = 0
        if isPassed {
            xp = lesson.xpReward + correct * GameRules.xpPerCorrectAnswer
            coins = GameRules.coinsPerLesson
            if isPerfect {
                xp += GameRules.perfectLessonBonusXP
                coins += GameRules.perfectLessonBonusCoins
            }
        }

        let summary = LessonSummary(
            lessonId: lesson.lessonId,
            skillKey: skillKey,
            totalExercises: total,
            correctFirstTry: correct,
            scorePercent: score,
            xpEarned: xp,
            coinsEarned: coins,
            isPerfect: isPerfect,
            isPassed: isPassed,
            ranOutOfHearts: ranOutOfHearts,
            heartsLeft: heartsLeft,
            duration: now().timeIntervalSince(startedAt),
            mistakes: mistakes,
            vocabularyOutcomes: vocabularyOutcomes,
            completedAt: now()
        )
        phase = .finished(summary)
    }

    private static func emptySummary(lessonId: String, skillKey: String, at date: Date) -> LessonSummary {
        LessonSummary(
            lessonId: lessonId,
            skillKey: skillKey,
            totalExercises: 0,
            correctFirstTry: 0,
            scorePercent: 0,
            xpEarned: 0,
            coinsEarned: 0,
            isPerfect: false,
            isPassed: false,
            ranOutOfHearts: false,
            heartsLeft: 0,
            duration: 0,
            mistakes: [],
            vocabularyOutcomes: [],
            completedAt: date
        )
    }
}
