import XCTest
@testable import Core

final class AchievementCatalogTests: XCTestCase {

    func testIdsAreUnique() {
        let ids = AchievementCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Ключи достижений должны быть уникальны")
    }

    func testTargetsArePositive() {
        for definition in AchievementCatalog.all {
            XCTAssertGreaterThan(definition.target, 0, "\(definition.id): порог должен быть больше нуля")
            XCTAssertFalse(definition.title.isEmpty)
            XCTAssertFalse(definition.detail.isEmpty)
            XCTAssertFalse(definition.symbolName.isEmpty)
        }
    }

    func testFirstAchievementsAreReachableEarly() {
        // Первая награда должна приходить за первый же урок — иначе прогресс не ощущается.
        let afterFirstLesson = AchievementStats(lessonsCompleted: 1)
        let unlocked = AchievementCatalog.all.filter {
            AchievementCatalog.progress(for: $0, stats: afterFirstLesson).isUnlocked
        }
        XCTAssertTrue(unlocked.contains { $0.id == "first_lesson" })
    }

    func testProgressIsCappedAtTarget() {
        let definition = try! XCTUnwrap(AchievementCatalog.definition(id: "ten_lessons"))
        let stats = AchievementStats(lessonsCompleted: 999)
        let progress = AchievementCatalog.progress(for: definition, stats: stats)
        XCTAssertEqual(progress.value, definition.target, "Прогресс не должен превышать порог")
        XCTAssertTrue(progress.isUnlocked)
    }

    func testProgressBeforeTarget() {
        let definition = try! XCTUnwrap(AchievementCatalog.definition(id: "streak_7"))
        let progress = AchievementCatalog.progress(for: definition, stats: AchievementStats(streak: 3))
        XCTAssertEqual(progress.value, 3)
        XCTAssertFalse(progress.isUnlocked)
    }

    func testNewlyUnlockedReturnsOnlyFreshOnes() {
        let before = AchievementStats(streak: 2, lessonsCompleted: 1)
        let after = AchievementStats(streak: 3, lessonsCompleted: 2)

        let fresh = AchievementCatalog.newlyUnlocked(before: before, after: after).map(\.id)

        XCTAssertTrue(fresh.contains("streak_3"), "Серия из 3 дней только что достигнута")
        XCTAssertFalse(fresh.contains("first_lesson"), "Это достижение было открыто раньше")
    }

    func testNothingUnlockedWhenStatsUnchanged() {
        let stats = AchievementStats(streak: 10, lessonsCompleted: 20, totalXP: 900)
        XCTAssertTrue(AchievementCatalog.newlyUnlocked(before: stats, after: stats).isEmpty)
    }

    func testEveryGoalKindIsCoveredByStats() {
        // Если появится новый вид цели, а в AchievementStats не будет счётчика,
        // value(for:) вернёт ноль и достижение никогда не откроется — ловим это здесь.
        let stats = AchievementStats(
            streak: 1, lessonsCompleted: 1, perfectLessons: 1,
            totalXP: 1, wordsLearned: 1, crowns: 1, skillsUnlocked: 1
        )
        for definition in AchievementCatalog.all {
            XCTAssertGreaterThan(
                stats.value(for: definition.goal), 0,
                "\(definition.id): счётчик для этой цели не заполняется"
            )
        }
    }

    func testTintKeysResolve() {
        let known: Set<String> = ["primary", "success", "danger", "warning", "xp", "coin", "gem", "heart", "streak"]
        for definition in AchievementCatalog.all {
            XCTAssertTrue(known.contains(definition.tintKey), "\(definition.id): неизвестный цвет \(definition.tintKey)")
        }
    }
}
