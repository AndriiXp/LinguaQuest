import XCTest
@testable import SRSEngine

/// Ожидаемые значения совпадают с Tools/reference_algorithms.py — если Swift и
/// Python-эталон разойдутся, тест упадёт на первой же сборке.
final class SM2SchedulerTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

    func testFirstSuccessfulReviewSetsOneDay() {
        let result = SM2Scheduler.schedule(
            SM2Scheduler.newCard(createdAt: day0),
            quality: .easy,
            reviewDate: day0,
            calendar: calendar
        )
        XCTAssertEqual(result.intervalDays, 1)
        XCTAssertEqual(result.repetitions, 1)
        XCTAssertEqual(result.lapses, 0)
        XCTAssertEqual(result.easeFactor, 2.6, accuracy: 0.0001)
    }

    func testSecondSuccessfulReviewSetsSixDays() {
        let state = SRSCardState(easeFactor: 2.6, intervalDays: 1, repetitions: 1)
        let result = SM2Scheduler.schedule(state, quality: .good, reviewDate: day0, calendar: calendar)
        XCTAssertEqual(result.intervalDays, 6)
        XCTAssertEqual(result.repetitions, 2)
        XCTAssertEqual(result.easeFactor, 2.6, accuracy: 0.0001)
    }

    func testThirdReviewMultipliesByEaseFactor() {
        let state = SRSCardState(easeFactor: 2.6, intervalDays: 6, repetitions: 2)
        let result = SM2Scheduler.schedule(state, quality: .good, reviewDate: day0, calendar: calendar)
        // round(6 * 2.6) = 16
        XCTAssertEqual(result.intervalDays, 16)
        XCTAssertEqual(result.repetitions, 3)
    }

    func testFailureResetsRepetitionsAndCountsLapse() {
        let state = SRSCardState(easeFactor: 2.5, intervalDays: 16, repetitions: 3, lapses: 0)
        let result = SM2Scheduler.schedule(state, quality: .wrongRemembered, reviewDate: day0, calendar: calendar)
        XCTAssertEqual(result.intervalDays, 1)
        XCTAssertEqual(result.repetitions, 0)
        XCTAssertEqual(result.lapses, 1)
        XCTAssertEqual(result.easeFactor, 1.96, accuracy: 0.0001)
    }

    func testEaseFactorNeverDropsBelowFloor() {
        var state = SRSCardState(easeFactor: 2.5, intervalDays: 10, repetitions: 3)
        for _ in 0..<12 {
            state = SM2Scheduler.schedule(state, quality: .blackout, reviewDate: day0, calendar: calendar)
        }
        XCTAssertEqual(state.easeFactor, SM2Scheduler.minimumEaseFactor, accuracy: 0.0001)
    }

    func testIntervalIsCapped() {
        let state = SRSCardState(easeFactor: 2.5, intervalDays: 300, repetitions: 5)
        let result = SM2Scheduler.schedule(state, quality: .easy, reviewDate: day0, calendar: calendar)
        XCTAssertEqual(result.intervalDays, SM2Scheduler.maximumIntervalDays)
    }

    func testNextReviewDateIsIntervalDaysAhead() {
        let state = SRSCardState(easeFactor: 2.5, intervalDays: 1, repetitions: 1)
        let result = SM2Scheduler.schedule(state, quality: .good, reviewDate: day0, calendar: calendar)
        let expected = calendar.date(byAdding: .day, value: 6, to: calendar.startOfDay(for: day0))!
        XCTAssertEqual(result.nextReviewDate, expected)
    }

    func testIsDueComparesByCalendarDay() {
        let state = SRSCardState(nextReviewDate: day0)
        XCTAssertTrue(SM2Scheduler.isDue(state, on: day0.addingTimeInterval(3600), calendar: calendar))
        XCTAssertFalse(SM2Scheduler.isDue(state, on: day0.addingTimeInterval(-86_400), calendar: calendar))
    }

    func testQualityInference() {
        XCTAssertEqual(ReviewQuality.infer(isCorrect: true, responseTime: 1.5, usedHint: false), .easy)
        XCTAssertEqual(ReviewQuality.infer(isCorrect: true, responseTime: 5, usedHint: false), .good)
        XCTAssertEqual(ReviewQuality.infer(isCorrect: true, responseTime: 20, usedHint: false), .hard)
        XCTAssertEqual(ReviewQuality.infer(isCorrect: true, responseTime: 2, usedHint: true), .hard)
        XCTAssertEqual(ReviewQuality.infer(isCorrect: false, responseTime: 2, usedHint: false), .blackout)
        XCTAssertTrue(ReviewQuality.blackout.isFailure)
        XCTAssertFalse(ReviewQuality.hard.isFailure)
    }
}
