import SwiftUI

/// Единая точка правды по визуальным константам приложения.
/// Все экраны обязаны брать отступы, радиусы и цвета отсюда, а не хардкодить числа.
public enum DS {

    // MARK: - Цвета

    public enum Colors {
        // Бренд
        public static let primary = Color.dynamic(light: "#6C5CE7", dark: "#8B7BFF")
        public static let primaryPressed = Color.dynamic(light: "#5A48D6", dark: "#7565F0")
        public static let primarySoft = Color.dynamic(light: "#EDEAFF", dark: "#2A2350")

        // Семантика ответов
        public static let success = Color.dynamic(light: "#16A34A", dark: "#4ADE80")
        public static let successSoft = Color.dynamic(light: "#DCFCE7", dark: "#14361F")
        public static let danger = Color.dynamic(light: "#DC2626", dark: "#F87171")
        public static let dangerSoft = Color.dynamic(light: "#FEE2E2", dark: "#3A1717")
        public static let warning = Color.dynamic(light: "#D97706", dark: "#FBBF24")

        // Игровая валюта и прогресс
        public static let xp = Color.dynamic(light: "#F59E0B", dark: "#FCD34D")
        public static let coin = Color.dynamic(light: "#EAB308", dark: "#FDE047")
        public static let gem = Color.dynamic(light: "#0EA5E9", dark: "#38BDF8")
        public static let heart = Color.dynamic(light: "#EF4444", dark: "#FB7185")
        public static let streak = Color.dynamic(light: "#F97316", dark: "#FDBA74")

        // Поверхности
        public static let background = Color.dynamic(light: "#F6F7FB", dark: "#0F1020")
        public static let surface = Color.dynamic(light: "#FFFFFF", dark: "#1A1B2E")
        public static let surfaceElevated = Color.dynamic(light: "#FFFFFF", dark: "#232445")
        public static let border = Color.dynamic(light: "#E2E5EF", dark: "#32345A")

        // Текст
        public static let textPrimary = Color.dynamic(light: "#12142B", dark: "#F5F6FF")
        public static let textSecondary = Color.dynamic(light: "#5B6079", dark: "#A6AAC8")
        public static let textOnPrimary = Color.dynamic(light: "#FFFFFF", dark: "#0F1020")

        /// Цвет по строковому ключу — нужен там, где оттенок задан данными,
        /// а не кодом (например, в каталоге достижений).
        public static func tint(_ key: String) -> Color {
            switch key {
            case "primary": return primary
            case "success": return success
            case "danger": return danger
            case "warning": return warning
            case "xp": return xp
            case "coin": return coin
            case "gem": return gem
            case "heart": return heart
            case "streak": return streak
            default: return textSecondary
            }
        }

        // Категории дерева навыков
        public static func category(_ key: String) -> Color {
            switch key {
            case "grammar":   return Color.dynamic(light: "#6C5CE7", dark: "#8B7BFF")
            case "vocab":     return Color.dynamic(light: "#0EA5E9", dark: "#38BDF8")
            case "listening": return Color.dynamic(light: "#16A34A", dark: "#4ADE80")
            case "speaking":  return Color.dynamic(light: "#EC4899", dark: "#F472B6")
            default:          return Color.dynamic(light: "#64748B", dark: "#94A3B8")
            }
        }
    }

    // MARK: - Отступы (шаг 4pt)

    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    // MARK: - Скругления

    public enum Radius {
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 24
        public static let pill: CGFloat = 999
    }

    // MARK: - Типографика (Dynamic Type — только системные стили)

    public enum Typography {
        public static let largeTitle = Font.largeTitle.weight(.bold)
        public static let title = Font.title2.weight(.bold)
        public static let headline = Font.headline
        public static let body = Font.body
        public static let bodyBold = Font.body.weight(.semibold)
        public static let callout = Font.callout
        public static let caption = Font.caption
        /// Крупный текст задания — растёт вместе с Dynamic Type.
        public static let exercisePrompt = Font.system(.title3, design: .rounded).weight(.semibold)
        public static let counter = Font.system(.subheadline, design: .rounded).weight(.bold)
    }

    // MARK: - Анимации

    public enum Motion {
        public static let quick = Animation.easeOut(duration: 0.18)
        public static let standard = Animation.spring(response: 0.35, dampingFraction: 0.82)
        public static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.6)
    }

    // MARK: - Размеры элементов

    public enum Size {
        public static let buttonHeight: CGFloat = 56
        public static let minTapTarget: CGFloat = 44
        public static let progressBarHeight: CGFloat = 12
        public static let skillNode: CGFloat = 76
    }
}
