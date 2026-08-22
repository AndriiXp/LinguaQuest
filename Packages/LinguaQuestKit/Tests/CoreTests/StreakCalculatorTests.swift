import XCTest
@testable import Core

final class StreakCalculatorTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// 1 699 963 200 = 2023-11-14 12:00 UTC. Полдень выбран намеренно:
    /// так прибавление суток не перескакивает границу дня из-за часовых поясов.
    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_699_963_200 + Double(offset) * 86_400)
    }

    // MARK: - refresh

    func testSameDayKeepsStreak() {
        let state = StreakState(count: 5, freezes: 0, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.refresh(state, now: day(0), calendar: calendar)
        XCTAssertEqual(updated.count, 5)
        XCTAssertEqual(event, .unchanged)
    }

    func testYesterdayKeepsStreakAlive() {
        let state = StreakState(count: 5, freezes: 0, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.refresh(state, now: day(1), calendar: calendar)
        XCTAssertEqual(updated.count, 5)
        XCTAssertEqual(event, .unchanged)
    }

    func testMissedDayWithoutFreezeResetsStreak() {
        let state = StreakState(count: 7, freezes: 0, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.refresh(state, now: day(2), calendar: calendar)
        XCTAssertEqual(updated.count, 0)
        XCTAssertNil(updated.lastActiveDay)
        XCTAssertEqual(event, .reset(missedDays: 1))
    }

    func testFreezeSavesStreak() {
        let state = StreakState(count: 7, freezes: 1, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.refresh(state, now: day(2), calendar: calendar)
        XCTAssertEqual(updated.count, 7)
        XCTAssertEqual(updated.freezes, 0)
        XCTAssertEqual(event, .savedByFreeze(used: 1))
    }

    func testNotEnoughFreezesResetsStreakButKeepsFreezes() {
        let state = StreakState(count: 7, freezes: 1, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.refresh(state, now: day(4), calendar: calendar)
        XCTAssertEqual(updated.count, 0)
        // Заморозки куплены за монеты — сгорать вместе с серией они не должны.
        XCTAssertEqual(updated.freezes, 1)
        XCTAssertEqual(event, .reset(missedDays: 3))
    }

    func testEmptyStreakIsUnchanged() {
        let state = StreakState(count: 0, freezes: 2, lastActiveDay: nil)
        let (updated, event) = StreakCalculator.refresh(state, now: day(10), calendar: calendar)
        XCTAssertEqual(updated.count, 0)
        XCTAssertEqual(event, .unchanged)
    }

    // MARK: - registerGoalReached

    func testFirstGoalStartsStreak() {
        let state = StreakState(count: 0, freezes: 0, lastActiveDay: nil)
        let (updated, event) = StreakCalculator.registerGoalReached(state, now: day(0), calendar: calendar)
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(event, .extended(to: 1))
        XCTAssertEqual(updated.lastActiveDay, calendar.startOfDay(for: day(0)))
    }

    func testConsecutiveDayExtendsStreak() {
        let state = StreakState(count: 3, freezes: 0, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.registerGoalReached(state, now: day(1), calendar: calendar)
        XCTAssertEqual(updated.count, 4)
        XCTAssertEqual(event, .extended(to: 4))
    }

    func testSecondGoalSameDayDoesNotDoubleCount() {
        let state = StreakState(count: 3, freezes: 0, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.registerGoalReached(state, now: day(0), calendar: calendar)
        XCTAssertEqual(updated.count, 3)
        XCTAssertEqual(event, .unchanged)
    }

    func testGapRestartsStreakFromOne() {
        let state = StreakState(count: 9, freezes: 0, lastActiveDay: day(0))
        let (updated, event) = StreakCalculator.registerGoalReached(state, now: day(5), calendar: calendar)
        XCTAssertEqual(updated.count, 1)
        XCTAssertEqual(event, .extended(to: 1))
    }

    func testDayGapIgnoresTimeOfDay() {
        let morning = day(0)
        let nextDayLate = morning.addingTimeInterval(86_400 + 3600 * 5)
        XCTAssertEqual(StreakCalculator.dayGap(from: morning, to: nextDayLate, calendar: calendar), 1)
        XCTAssertEqual(StreakCalculator.dayGap(from: nextDayLate, to: morning, calendar: calendar), 0)
    }
}
