import XCTest
@testable import Core

final class ProgressionTests: XCTestCase {

    func testLevelThresholds() {
        XCTAssertEqual((1...6).map(Progression.totalXP(forLevel:)), [0, 50, 150, 300, 500, 750])
    }

    func testLevelForTotalXP() {
        let cases: [(xp: Int, level: Int)] = [
            (0, 1), (49, 1), (50, 2), (149, 2), (150, 3), (299, 3), (300, 4), (500, 5),
            // 25*63*62 = 97 650 <= 100 000 < 25*64*63 = 100 800
            (100_000, 63)
        ]
        for (xp, level) in cases {
            XCTAssertEqual(Progression.level(forTotalXP: xp), level, "xp = \(xp)")
        }
    }

    func testNegativeXPIsClampedToFirstLevel() {
        XCTAssertEqual(Progression.level(forTotalXP: -100), 1)
    }

    func testLevelIsMonotonicAndConsistentWithThresholds() {
        var previous = 1
        for xp in stride(from: 0, to: 20_000, by: 7) {
            let level = Progression.level(forTotalXP: xp)
            XCTAssertGreaterThanOrEqual(level, previous)
            XCTAssertLessThanOrEqual(Progression.totalXP(forLevel: level), xp)
            XCTAssertGreaterThan(Progression.totalXP(forLevel: level + 1), xp)
            previous = level
        }
    }

    func testProgressWithinLevel() {
        // 150 XP — ровно начало третьего уровня, следующий стоит 150 XP.
        XCTAssertEqual(Progression.xpInCurrentLevel(totalXP: 150), 0)
        XCTAssertEqual(Progression.xpNeededForNextLevel(totalXP: 150), 150)
        XCTAssertEqual(Progression.levelProgress(totalXP: 150), 0, accuracy: 0.0001)

        XCTAssertEqual(Progression.xpInCurrentLevel(totalXP: 225), 75)
        XCTAssertEqual(Progression.levelProgress(totalXP: 225), 0.5, accuracy: 0.0001)
    }

    func testProgressIsAlwaysInUnitRange() {
        for xp in stride(from: 0, to: 5_000, by: 13) {
            let progress = Progression.levelProgress(totalXP: xp)
            XCTAssertGreaterThanOrEqual(progress, 0)
            XCTAssertLessThanOrEqual(progress, 1)
        }
    }
}
