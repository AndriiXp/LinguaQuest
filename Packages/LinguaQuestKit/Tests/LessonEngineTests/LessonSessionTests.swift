import XCTest
import ContentModels
import Core
@testable import LessonEngine

final class LessonSessionTests: XCTestCase {

    // MARK: - Фикстуры

    private func choiceExercise(id: String, correct: String = "drinks") -> Exercise {
        Exercise(
            id: id,
            type: .multipleChoice,
            prompt: "She ___ coffee.",
            correctAnswer: correct,
            options: [correct, "drink", "drinking"],
            explanation: "Третье лицо единственного числа.",
            difficulty: 1,
            vocabularyIds: ["v_drink"],
            errorCategory: "tense"
        )
    }

    private func typeExercise(id: String) -> Exercise {
        Exercise(
            id: id,
            type: .typeAnswer,
            prompt: "Переведите: завтрак",
            correctAnswer: "breakfast",
            difficulty: 2,
            vocabularyIds: ["v_breakfast"],
            errorCategory: "spelling"
        )
    }

    private func pairsExercise(id: String) -> Exercise {
        Exercise(
            id: id,
            type: .matchPairs,
            prompt: "Соедините пары",
            pairs: [
                MatchPair(id: "p1", left: "water", right: "вода"),
                MatchPair(id: "p2", left: "bread", right: "хлеб")
            ],
            difficulty: 1,
            vocabularyIds: ["v_water", "v_bread"]
        )
    }

    private func lesson(_ exercises: [Exercise], xpReward: Int = 20) -> LessonContent {
        LessonContent(
            lessonId: "test_lesson",
            title: "Тест",
            orderIndex: 1,
            xpReward: xpReward,
            exercises: exercises
        )
    }

    private func makeSession(
        _ exercises: [Exercise],
        hearts: HeartsState = HeartsState(),
        xpReward: Int = 20
    ) -> LessonSession {
        LessonSession(
            lesson: lesson(exercises, xpReward: xpReward),
            skillKey: "test_skill",
            hearts: hearts
        )
    }

    // MARK: - Базовый поток

    func testCorrectAnswerAdvancesWithoutLosingHearts() {
        let session = makeSession([choiceExercise(id: "e1"), choiceExercise(id: "e2")])

        let feedback = session.submit(.choice("drinks"))

        XCTAssertEqual(feedback.verdict, .correct)
        XCTAssertEqual(session.heartsLeft, GameRules.maxHearts)
        XCTAssertEqual(session.completedCount, 1)

        session.advance()
        XCTAssertEqual(session.currentExercise?.id, "e2")
        if case .question = session.phase {} else { XCTFail("Ожидалась фаза вопроса") }
    }

    func testWrongAnswerCostsHeartAndLogsMistake() {
        let session = makeSession([choiceExercise(id: "e1")])

        let feedback = session.submit(.choice("drink"))

        XCTAssertEqual(feedback.verdict, .incorrect)
        XCTAssertEqual(feedback.correctAnswer, "drinks")
        XCTAssertEqual(session.heartsLeft, GameRules.maxHearts - 1)
        XCTAssertEqual(session.mistakes.count, 1)
        XCTAssertEqual(session.mistakes.first?.userAnswer, "drink")
        XCTAssertEqual(session.mistakes.first?.errorCategory, "tense")
    }

    func testFailedExerciseReturnsToQueueAndMustBeSolved() {
        let session = makeSession([choiceExercise(id: "e1"), choiceExercise(id: "e2")])

        session.submit(.choice("drink"))   // ошибка на e1
        session.advance()
        XCTAssertEqual(session.currentExercise?.id, "e2")

        session.submit(.choice("drinks"))  // верно на e2
        session.advance()
        // e1 вернулось в конец очереди.
        XCTAssertEqual(session.currentExercise?.id, "e1")

        session.submit(.choice("drinks"))
        session.advance()

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Урок должен был завершиться")
        }
        // e1 решено со второй попытки — в зачёт «с первой попытки» не идёт.
        XCTAssertEqual(summary.correctFirstTry, 1)
        XCTAssertEqual(summary.totalExercises, 2)
        XCTAssertEqual(summary.scorePercent, 50)
    }

    func testRequeueIsLimitedSoLessonAlwaysEnds() {
        let session = makeSession([choiceExercise(id: "e1")], hearts: HeartsState(count: 99))

        var guardCounter = 0
        while !session.isFinished && guardCounter < 20 {
            if case .outOfHearts = session.phase { break }
            session.submit(.choice("drink"))
            session.advance()
            guardCounter += 1
        }

        XCTAssertTrue(session.isFinished, "Урок обязан завершиться, а не крутиться бесконечно")
        XCTAssertLessThanOrEqual(guardCounter, 4)
    }

    // MARK: - Опечатки

    func testTypoIsAcceptedAndDoesNotCostHeart() {
        let session = makeSession([typeExercise(id: "t1")])

        let feedback = session.submit(.text("breakfost"))

        XCTAssertEqual(feedback.verdict, .almost)
        XCTAssertEqual(feedback.correctAnswer, "breakfast")
        XCTAssertEqual(session.heartsLeft, GameRules.maxHearts)
        XCTAssertTrue(session.mistakes.isEmpty)
    }

    // MARK: - Сопоставление пар

    func testMatchPairsCompletesOnlyAfterAllPairs() {
        let session = makeSession([pairsExercise(id: "m1")])

        let first = session.submit(.pairMatch(pairId: "p1", right: "вода"))
        XCTAssertEqual(first.verdict, .correct)
        XCTAssertTrue(first.awaitingMorePairs)
        if case .question = session.phase {} else { XCTFail("Задание ещё не закончено") }

        let second = session.submit(.pairMatch(pairId: "p2", right: "хлеб"))
        XCTAssertFalse(second.awaitingMorePairs)
        if case .feedback = session.phase {} else { XCTFail("Ожидалась обратная связь") }
    }

    func testWrongPairCostsHeartButExerciseContinues() {
        let session = makeSession([pairsExercise(id: "m1")])

        let feedback = session.submit(.pairMatch(pairId: "p1", right: "хлеб"))

        XCTAssertEqual(feedback.verdict, .incorrect)
        XCTAssertTrue(feedback.awaitingMorePairs)
        XCTAssertEqual(session.heartsLeft, GameRules.maxHearts - 1)
        XCTAssertEqual(session.mistakes.count, 1)

        session.submit(.pairMatch(pairId: "p1", right: "вода"))
        session.submit(.pairMatch(pairId: "p2", right: "хлеб"))
        session.advance()

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Урок должен завершиться")
        }
        // Пары собраны, но не безошибочно — в зачёт с первой попытки не идёт.
        XCTAssertEqual(summary.correctFirstTry, 0)
    }

    // MARK: - Сердца

    func testRunningOutOfHeartsStopsLesson() {
        let session = makeSession(
            [choiceExercise(id: "e1"), choiceExercise(id: "e2")],
            hearts: HeartsState(count: 1)
        )

        session.submit(.choice("drink"))

        if case .outOfHearts = session.phase {} else {
            XCTFail("Ожидалась фаза «сердца кончились»")
        }
        XCTAssertEqual(session.heartsLeft, 0)
    }

    func testAbandonedLessonGivesNoRewards() {
        let session = makeSession(
            [choiceExercise(id: "e1"), choiceExercise(id: "e2")],
            hearts: HeartsState(count: 1)
        )
        session.submit(.choice("drink"))
        session.abandon()

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Ожидалось завершение")
        }
        XCTAssertTrue(summary.ranOutOfHearts)
        XCTAssertFalse(summary.isPassed)
        XCTAssertEqual(summary.xpEarned, 0)
        XCTAssertEqual(summary.coinsEarned, 0)
    }

    func testRefillHeartsResumesLesson() {
        let session = makeSession([choiceExercise(id: "e1")], hearts: HeartsState(count: 1))
        session.submit(.choice("drink"))
        session.refillHearts()

        XCTAssertEqual(session.heartsLeft, GameRules.maxHearts)
        if case .question = session.phase {} else { XCTFail("Урок должен продолжиться") }
    }

    // MARK: - Итог

    func testPerfectLessonRewards() {
        let exercises = (1...5).map { choiceExercise(id: "e\($0)") }
        let session = makeSession(exercises, xpReward: 20)

        for _ in exercises {
            session.submit(.choice("drinks"))
            session.advance()
        }

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Ожидалось завершение")
        }
        XCTAssertTrue(summary.isPerfect)
        XCTAssertTrue(summary.isPassed)
        XCTAssertEqual(summary.scorePercent, 100)
        // 20 базовых + 5 верных * 2 + 10 бонус = 40
        XCTAssertEqual(summary.xpEarned, 40)
        // 5 за урок + 3 бонус
        XCTAssertEqual(summary.coinsEarned, 8)
    }

    func testScoreBelowPassingGivesNoXP() {
        // Три задания, два провалены дважды — итоговый балл ниже проходного.
        let exercises = [choiceExercise(id: "e1"), choiceExercise(id: "e2"), choiceExercise(id: "e3")]
        let session = makeSession(exercises, hearts: HeartsState(count: 99))

        session.submit(.choice("drinks"))  // e1 верно
        session.advance()
        session.submit(.choice("drink"))   // e2 ошибка
        session.advance()
        session.submit(.choice("drink"))   // e3 ошибка
        session.advance()
        // Повторы e2 и e3.
        session.submit(.choice("drinks"))
        session.advance()
        session.submit(.choice("drinks"))
        session.advance()

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Ожидалось завершение")
        }
        XCTAssertEqual(summary.correctFirstTry, 1)
        XCTAssertEqual(summary.scorePercent, 33)
        XCTAssertFalse(summary.isPassed)
        XCTAssertEqual(summary.xpEarned, 0)
    }

    func testVocabularyOutcomesAreCollected() {
        let session = makeSession([choiceExercise(id: "e1"), typeExercise(id: "t1")])
        session.submit(.choice("drinks"))
        session.advance()
        session.submit(.text("breakfast"))
        session.advance()

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Ожидалось завершение")
        }
        XCTAssertEqual(Set(summary.vocabularyOutcomes.map(\.itemId)), ["v_drink", "v_breakfast"])
        XCTAssertTrue(summary.vocabularyOutcomes.allSatisfy(\.isCorrect))
    }

    func testProgressReachesOneOnCompletion() {
        let session = makeSession([choiceExercise(id: "e1"), choiceExercise(id: "e2")])
        XCTAssertEqual(session.progress, 0)

        session.submit(.choice("drinks"))
        session.advance()
        XCTAssertEqual(session.progress, 0.5, accuracy: 0.001)

        session.submit(.choice("drinks"))
        session.advance()
        XCTAssertEqual(session.progress, 1, accuracy: 0.001)
    }

    func testEmptyLessonFinishesImmediately() {
        let session = makeSession([])
        guard case .finished(let summary) = session.phase else {
            return XCTFail("Пустой урок должен сразу завершаться")
        }
        XCTAssertEqual(summary.totalExercises, 0)
        XCTAssertFalse(summary.isPassed)
    }
}
