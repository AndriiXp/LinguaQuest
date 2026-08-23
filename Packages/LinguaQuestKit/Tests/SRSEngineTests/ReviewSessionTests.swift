import XCTest
@testable import SRSEngine

final class ReviewSessionTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let day0 = Date(timeIntervalSince1970: 1_699_963_200)

    private func item(_ id: String, repetitions: Int = 1, interval: Int = 1) -> ReviewItem {
        ReviewItem(
            id: id,
            word: "word_\(id)",
            translation: "перевод_\(id)",
            state: SRSCardState(easeFactor: 2.5, intervalDays: interval, repetitions: repetitions)
        )
    }

    private func makeSession(_ items: [ReviewItem]) -> ReviewSession {
        ReviewSession(items: items, now: { self.day0 }, calendar: calendar)
    }

    // MARK: - Поток

    func testStartsWithFirstItemHidden() {
        let session = makeSession([item("a"), item("b")])
        XCTAssertEqual(session.currentItem?.id, "a")
        XCTAssertEqual(session.phase, .recalling)
        XCTAssertEqual(session.totalCount, 2)
        XCTAssertEqual(session.completedCount, 0)
    }

    func testRevealThenRateMovesToNext() {
        let session = makeSession([item("a"), item("b")])

        session.reveal()
        XCTAssertEqual(session.phase, .revealed)

        session.rate(.easy)
        XCTAssertEqual(session.currentItem?.id, "b")
        XCTAssertEqual(session.phase, .recalling)
        XCTAssertEqual(session.completedCount, 1)
    }

    func testRatingIgnoredBeforeReveal() {
        let session = makeSession([item("a"), item("b")])
        // Оценка без раскрытия перевода — это самообман, движок её не принимает.
        session.rate(.easy)
        XCTAssertEqual(session.currentItem?.id, "a")
        XCTAssertEqual(session.completedCount, 0)
    }

    func testForgottenCardComesBackOnceInSameSession() {
        let session = makeSession([item("a"), item("b")])

        session.reveal()
        session.rate(.forgot)          // «а» уходит в конец очереди
        XCTAssertEqual(session.currentItem?.id, "b")
        XCTAssertEqual(session.completedCount, 0, "Забытая карточка ещё не закрыта")

        session.reveal()
        session.rate(.easy)            // «b» закрыта
        XCTAssertEqual(session.currentItem?.id, "a")

        session.reveal()
        session.rate(.forgot)          // повторно забыли — второй раз не возвращаем
        guard case .finished = session.phase else {
            return XCTFail("Сессия должна завершиться, а не крутить карточку бесконечно")
        }
    }

    func testEmptySessionFinishesImmediately() {
        let session = makeSession([])
        guard case .finished(let summary) = session.phase else {
            return XCTFail("Пустая сессия должна сразу завершаться")
        }
        XCTAssertEqual(summary.total, 0)
        XCTAssertEqual(summary.accuracyPercent, 0)
    }

    // MARK: - Расписание

    func testEasyRatingSchedulesFurtherThanHard() {
        let easySession = makeSession([item("a", repetitions: 2, interval: 6)])
        easySession.reveal()
        easySession.rate(.easy)

        let hardSession = makeSession([item("a", repetitions: 2, interval: 6)])
        hardSession.reveal()
        hardSession.rate(.hard)

        guard case .finished(let easySummary) = easySession.phase,
              case .finished(let hardSummary) = hardSession.phase else {
            return XCTFail("Обе сессии должны завершиться")
        }

        let easyEase = easySummary.outcomes[0].updatedState.easeFactor
        let hardEase = hardSummary.outcomes[0].updatedState.easeFactor
        XCTAssertGreaterThan(easyEase, hardEase, "«Легко» должно повышать easeFactor сильнее, чем «с трудом»")
    }

    func testForgottenCardResetsInterval() {
        let session = makeSession([item("a", repetitions: 4, interval: 30)])
        session.reveal()
        session.rate(.forgot)
        session.reveal()
        session.rate(.forgot)

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Ожидалось завершение")
        }
        let state = summary.outcomes[0].updatedState
        XCTAssertEqual(state.intervalDays, 1, "Забытое слово возвращается на завтра")
        XCTAssertEqual(state.repetitions, 0)
        XCTAssertGreaterThan(state.lapses, 0)
    }

    // MARK: - Итог

    func testSummaryCountsRememberedAndForgotten() {
        let session = makeSession([item("a"), item("b"), item("c")])

        session.reveal(); session.rate(.easy)     // a — помним
        session.reveal(); session.rate(.hard)     // b — помним с трудом
        session.reveal(); session.rate(.forgot)   // c — забыли, вернётся
        session.reveal(); session.rate(.hard)     // c со второго раза

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Ожидалось завершение")
        }
        XCTAssertEqual(summary.total, 3, "Каждое слово считается один раз, даже если показано дважды")
        XCTAssertEqual(summary.remembered, 3)
        XCTAssertEqual(summary.forgotten, 0, "Последняя оценка по слову перекрывает предыдущую")
        XCTAssertEqual(summary.accuracyPercent, 100)
    }

    func testAbandonKeepsRatedCards() {
        let session = makeSession([item("a"), item("b"), item("c")])
        session.reveal()
        session.rate(.easy)
        session.abandon()

        guard case .finished(let summary) = session.phase else {
            return XCTFail("Ожидалось завершение")
        }
        XCTAssertEqual(summary.total, 1, "В итог попадают только оценённые карточки")
        XCTAssertEqual(summary.remembered, 1)
    }

    func testProgressReachesOne() {
        let session = makeSession([item("a"), item("b")])
        XCTAssertEqual(session.progress, 0)

        session.reveal(); session.rate(.easy)
        XCTAssertEqual(session.progress, 0.5, accuracy: 0.001)

        session.reveal(); session.rate(.easy)
        XCTAssertEqual(session.progress, 1, accuracy: 0.001)
    }

    func testRecallRatingMapsToQuality() {
        XCTAssertTrue(RecallRating.forgot.quality.isFailure)
        XCTAssertFalse(RecallRating.hard.quality.isFailure)
        XCTAssertFalse(RecallRating.easy.quality.isFailure)
        XCTAssertEqual(RecallRating.allCases.count, 3)
    }
}
