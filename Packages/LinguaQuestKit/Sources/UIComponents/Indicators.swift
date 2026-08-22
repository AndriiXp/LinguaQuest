import SwiftUI
import Core

/// Полоса прогресса урока.
public struct LessonProgressBar: View {
    private let progress: Double

    public init(progress: Double) {
        self.progress = min(1, max(0, progress))
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DS.Colors.border)
                Capsule()
                    .fill(DS.Colors.success)
                    .frame(width: max(0, geometry.size.width * progress))
            }
        }
        .frame(height: DS.Size.progressBarHeight)
        .animation(DS.Motion.standard, value: progress)
        .accessibilityLabel("Прогресс урока")
        .accessibilityValue("\(Int(progress * 100)) процентов")
    }
}

/// Индикатор сердец.
public struct HeartsIndicator: View {
    private let count: Int
    private let maximum: Int

    public init(count: Int, maximum: Int = GameRules.maxHearts) {
        self.count = count
        self.maximum = maximum
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: count > 0 ? "heart.fill" : "heart")
                .foregroundStyle(DS.Colors.heart)
            Text("\(count)")
                .font(DS.Typography.counter)
                .foregroundStyle(DS.Colors.textPrimary)
                .contentTransition(.numericText())
        }
        .animation(DS.Motion.bouncy, value: count)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Осталось жизней: \(count) из \(maximum)")
    }
}

/// Универсальный чип со значением: XP, монеты, streak, гемы.
public struct StatChip: View {
    public enum Kind {
        case xp, coins, gems, streak

        var symbol: String {
            switch self {
            case .xp: return "bolt.fill"
            case .coins: return "circle.hexagongrid.fill"
            case .gems: return "diamond.fill"
            case .streak: return "flame.fill"
            }
        }

        var tint: Color {
            switch self {
            case .xp: return DS.Colors.xp
            case .coins: return DS.Colors.coin
            case .gems: return DS.Colors.gem
            case .streak: return DS.Colors.streak
            }
        }

        var accessibilityName: String {
            switch self {
            case .xp: return "Опыт"
            case .coins: return "Монеты"
            case .gems: return "Кристаллы"
            case .streak: return "Серия дней"
            }
        }
    }

    private let kind: Kind
    private let value: Int

    public init(kind: Kind, value: Int) {
        self.kind = kind
        self.value = value
    }

    public var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind.tint)
            Text("\(value)")
                .font(DS.Typography.counter)
                .foregroundStyle(DS.Colors.textPrimary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xxs)
        .background(Capsule().fill(DS.Colors.surface))
        .overlay(Capsule().strokeBorder(DS.Colors.border, lineWidth: 1))
        .animation(DS.Motion.standard, value: value)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.accessibilityName): \(value)")
    }
}

/// Аватар игрока: SF Symbol на фирменном градиенте.
public struct AvatarBadge: View {
    private let avatar: AvatarItem
    private let size: CGFloat
    private let isLocked: Bool

    public init(avatar: AvatarItem, size: CGFloat = 64, isLocked: Bool = false) {
        self.avatar = avatar
        self.size = size
        self.isLocked = isLocked
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(avatar.gradient)
            Image(systemName: isLocked ? "lock.fill" : avatar.symbolName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .opacity(isLocked ? 0.45 : 1)
        .accessibilityLabel(isLocked ? "\(avatar.title), закрыт" : avatar.title)
    }
}

/// Полоса XP до следующего уровня.
public struct LevelProgressView: View {
    private let level: Int
    private let progress: Double
    private let xpInLevel: Int
    private let xpNeeded: Int

    public init(level: Int, progress: Double, xpInLevel: Int, xpNeeded: Int) {
        self.level = level
        self.progress = progress
        self.xpInLevel = xpInLevel
        self.xpNeeded = xpNeeded
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack {
                Text("Уровень \(level)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                Spacer()
                Text("\(xpInLevel) / \(xpNeeded) XP")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(DS.Colors.border)
                    Capsule()
                        .fill(DS.Colors.xp)
                        .frame(width: max(0, geometry.size.width * min(1, max(0, progress))))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Уровень \(level), \(xpInLevel) из \(xpNeeded) очков опыта")
    }
}
