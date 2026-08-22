import XCTest
@testable import Core

final class AvatarCatalogTests: XCTestCase {

    func testCatalogHasUniqueIds() {
        let ids = AvatarCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Идентификаторы аватаров должны быть уникальны")
    }

    func testDefaultAvatarsExist() {
        XCTAssertFalse(AvatarCatalog.defaults.isEmpty, "Нужен стартовый набор, иначе профиль будет без аватара")
    }

    func testDefaultProfileAvatarIsInCatalog() {
        // UserProfile создаётся с selectedAvatarId = "fox".
        XCTAssertNotNil(AvatarCatalog.item(id: "fox"))
        XCTAssertTrue(AvatarCatalog.defaults.contains { $0.id == "fox" })
    }

    func testLevelUnlocks() {
        let atLevelOne = AvatarCatalog.unlockedBy(level: 1)
        XCTAssertTrue(atLevelOne.isEmpty, "На первом уровне ничего дополнительно не открыто")

        let atLevelFive = AvatarCatalog.unlockedBy(level: 5).map(\.id)
        XCTAssertTrue(atLevelFive.contains("rocket"))
        XCTAssertTrue(atLevelFive.contains("wizard"))
        XCTAssertFalse(atLevelFive.contains("dragon"))
    }

    func testAvailabilityRules() {
        let byLevel = AvatarCatalog.all.first { $0.id == "dragon" }!
        XCTAssertFalse(AvatarCatalog.isAvailable(byLevel, level: 5, ownedIds: []))
        XCTAssertTrue(AvatarCatalog.isAvailable(byLevel, level: 10, ownedIds: []))

        let purchasable = AvatarCatalog.all.first { $0.id == "crown" }!
        XCTAssertFalse(AvatarCatalog.isAvailable(purchasable, level: 50, ownedIds: []))
        XCTAssertTrue(AvatarCatalog.isAvailable(purchasable, level: 1, ownedIds: ["crown"]))

        let free = AvatarCatalog.all.first { $0.id == "fox" }!
        XCTAssertTrue(AvatarCatalog.isAvailable(free, level: 1, ownedIds: []))
    }

    func testGradientsAreWellFormed() {
        for avatar in AvatarCatalog.all {
            XCTAssertGreaterThanOrEqual(avatar.gradientHex.count, 2, "\(avatar.id): нужен градиент из двух цветов")
            XCTAssertFalse(avatar.symbolName.isEmpty)
        }
    }
}
