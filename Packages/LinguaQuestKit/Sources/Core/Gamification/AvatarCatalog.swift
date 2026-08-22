import Foundation
import SwiftUI

/// Как аватар открывается.
public enum AvatarUnlock: Equatable, Sendable {
    case `default`
    case level(Int)
    case coins(Int)
    case gems(Int)
}

/// Аватар персонажа. На старте это SF Symbol на фирменном градиенте —
/// не требует ассетов, идеально масштабируется и не нарушает ничьих прав.
/// Когда появятся собственные иллюстрации, достаточно добавить поле assetName.
public struct AvatarItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let category: String
    public let symbolName: String
    public let gradientHex: [String]
    public let unlock: AvatarUnlock

    public init(
        id: String,
        title: String,
        category: String,
        symbolName: String,
        gradientHex: [String],
        unlock: AvatarUnlock
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.symbolName = symbolName
        self.gradientHex = gradientHex
        self.unlock = unlock
    }

    public var gradient: LinearGradient {
        LinearGradient(
            colors: gradientHex.map { Color(hex: $0) },
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Статический каталог аватаров.
public enum AvatarCatalog {

    public static let all: [AvatarItem] = [
        // Стартовые
        AvatarItem(id: "fox", title: "Лис", category: "animals", symbolName: "pawprint.fill",
                   gradientHex: ["#F97316", "#FB923C"], unlock: .default),
        AvatarItem(id: "owl", title: "Сова", category: "animals", symbolName: "bird.fill",
                   gradientHex: ["#6C5CE7", "#8B7BFF"], unlock: .default),
        AvatarItem(id: "cat", title: "Кот", category: "animals", symbolName: "cat.fill",
                   gradientHex: ["#0EA5E9", "#38BDF8"], unlock: .default),

        // За уровень
        AvatarItem(id: "rocket", title: "Ракета", category: "characters", symbolName: "airplane",
                   gradientHex: ["#EC4899", "#F472B6"], unlock: .level(3)),
        AvatarItem(id: "wizard", title: "Маг", category: "characters", symbolName: "wand.and.stars",
                   gradientHex: ["#7C3AED", "#A78BFA"], unlock: .level(5)),
        AvatarItem(id: "dragon", title: "Дракон", category: "characters", symbolName: "flame.fill",
                   gradientHex: ["#DC2626", "#F87171"], unlock: .level(10)),
        AvatarItem(id: "scholar", title: "Учёный", category: "characters", symbolName: "graduationcap.fill",
                   gradientHex: ["#0F766E", "#2DD4BF"], unlock: .level(15)),

        // За валюту
        AvatarItem(id: "crown", title: "Корона", category: "emoji", symbolName: "crown.fill",
                   gradientHex: ["#EAB308", "#FDE047"], unlock: .coins(500)),
        AvatarItem(id: "star", title: "Звезда", category: "emoji", symbolName: "star.fill",
                   gradientHex: ["#F59E0B", "#FCD34D"], unlock: .coins(300)),
        AvatarItem(id: "diamond", title: "Алмаз", category: "emoji", symbolName: "diamond.fill",
                   gradientHex: ["#06B6D4", "#67E8F9"], unlock: .gems(50))
    ]

    public static func item(id: String) -> AvatarItem? {
        all.first { $0.id == id }
    }

    /// Аватары, доступные сразу после установки.
    public static var defaults: [AvatarItem] {
        all.filter { $0.unlock == .default }
    }

    /// Какие аватары открываются при достижении уровня.
    public static func unlockedBy(level: Int) -> [AvatarItem] {
        all.filter {
            if case .level(let required) = $0.unlock { return required <= level }
            return false
        }
    }

    /// Доступен ли аватар при данном уровне и наборе купленных.
    public static func isAvailable(_ item: AvatarItem, level: Int, ownedIds: Set<String>) -> Bool {
        switch item.unlock {
        case .default: return true
        case .level(let required): return level >= required
        case .coins, .gems: return ownedIds.contains(item.id)
        }
    }
}
