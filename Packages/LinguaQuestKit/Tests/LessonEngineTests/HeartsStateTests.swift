import XCTest
import Core
@testable import LessonEngine

final class HeartsStateTests: XCTestCase {

    private let base = Date(timeIntervalSince1970: 1_699_963_200)

    private func minutes(_ value: Double) -> Date {
        base.addingTimeInterval(value * 60)
    }

    func testNewStateIsFull() {
        XCTAssertEqual(HeartsState().current(at: base), GameRules.maxHearts)
        XCTAssertFalse(HeartsState().isEmpty(at: base))
    }

    func testCountIsClampedToBounds() {
        XCTAssertEqual(HeartsState(count: 99).current(at: base), GameRules.maxHearts)
        XCTAssertEqual(HeartsState(count: -3).current(at: base), 0)
    }

    func testSpendingReducesByOne() {
        let state = HeartsState().spending(at: base)
        XCTAssertEqual(state.current(at: base), GameRules.maxHearts - 1)
    }

    func testSpendingAtZeroStaysZero() {
        let state = HeartsState(count: 0, lastSpentAt: base).spending(at: base)
        XCTAssertEqual(state.current(at: base), 0)
        XCTAssertTrue(state.isEmpty(at: base))
    }

    func testRegenerationAddsHeartPerPeriod() {
        let state = HeartsState(count: 2, lastSpentAt: base)
        XCTAssertEqual(state.current(at: minutes(29)), 2)
        XCTAssertEqual(state.current(at: minutes(30)), 3)
        XCTAssertEqual(state.current(at: minutes(61)), 4)
        XCTAssertEqual(state.current(at: minutes(600)), GameRules.maxHearts)
    }

    func testFullStateDoesNotRegenerate() {
        let state = HeartsState(count: GameRules.maxHearts, lastSpentAt: base)
        XCTAssertEqual(state.current(at: minutes(600)), GameRules.maxHearts)
        XCTAssertNil(state.secondsUntilNextHeart(at: minutes(600)))
    }

    func testSpendingAfterRegenerationUsesActualCount() {
        // Было 2 сердца, прошёл час — стало 4, тратим одно → 3.
        let state = HeartsState(count: 2, lastSpentAt: base)
        let afterSpend = state.spending(at: minutes(60))
        XCTAssertEqual(afterSpend.current(at: minutes(60)), 3)
    }

    func testSecondsUntilNextHeart() throws {
        let state = HeartsState(count: 1, lastSpentAt: base)
        let remaining = try XCTUnwrap(state.secondsUntilNextHeart(at: minutes(10)))
        XCTAssertEqual(remaining, 20 * 60, accuracy: 1)
    }

    func testRefillRestoresEverything() {
        let state = HeartsState(count: 0, lastSpentAt: base).refilled()
        XCTAssertEqual(state.current(at: base), GameRules.maxHearts)
        XCTAssertNil(state.secondsUntilNextHeart(at: base))
    }
}
