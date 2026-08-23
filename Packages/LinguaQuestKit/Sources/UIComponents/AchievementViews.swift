import SwiftUI
import Core

/// Значок достижения: открытые — в цвете, закрытые — приглушённые с прогрессом.
public struct AchievementBadge: View {
    private let definition: AchievementDefinition
    private let progress: Int
    private let isUnlocked: Bool

    public init(definition: AchievementDefinition, progress: Int, isUnlocked: Bool) {
        self.definition = definition
        self.progress = progress
        self.isUnlocked = isUnlocked
    }

    private var tint: Color { DS.Colors.tint(definition.tintKey) }
    private var ratio: Double {
        guard definition.target > 0 else { return 0 }
        return min(1, Double(progress) / Double(definition.target))
    }

    public var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? tint.opacity(0.18) : DS.Colors.border.opacity(0.5))

                if !isUnlocked {
                    // Кольцо прогресса показывает, сколько осталось до награды.
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(2)
                }

                Image(systemName: definition.symbolName)
                    .font(.system(size: 24))
                    .foregroundStyle(isUnlocked ? tint : DS.Colors.textSecondary)
            }
            .frame(width: 64, height: 64)

            Text(definition.title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(isUnlocked ? "Получено" : "\(progress) / \(definition.target)")
                .font(.caption2)
                .foregroundStyle(DS.Colors.textSecondary)
                .monospacedDigit()
        }
        .opacity(isUnlocked ? 1 : 0.75)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            isUnlocked
                ? "\(definition.title). Получено. \(definition.detail)"
                : "\(definition.title). \(definition.detail). Прогресс \(progress) из \(definition.target)"
        )
    }
}

/// Календарь занятий: столбцы — недели, строки — дни недели.
/// Насыщенность клетки показывает, сколько XP набрано в этот день.
public struct ActivityCalendar: View {
    private let activity: [Date: Int]
    private let weeks: Int
    private let dailyGoal: Int
    private let calendar: Calendar
    private let today: Date

    public init(
        activity: [Date: Int],
        weeks: Int = 13,
        dailyGoal: Int = 20,
        calendar: Calendar = .current,
        today: Date = Date()
    ) {
        self.activity = activity
        self.weeks = weeks
        self.dailyGoal = max(1, dailyGoal)
        self.calendar = calendar
        self.today = today
    }

    /// Дни от начала недели, в которую попадает самый ранний показанный день, до сегодня.
    private var days: [Date] {
        let end = calendar.startOfDay(for: today)
        // Выравниваем сетку по началу недели, чтобы столбцы были целыми неделями.
        let weekday = calendar.component(.weekday, from: end)
        let firstWeekday = calendar.firstWeekday
        let offsetToWeekEnd = (firstWeekday + 6 - weekday + 7) % 7
        guard let gridEnd = calendar.date(byAdding: .day, value: offsetToWeekEnd, to: end),
              let start = calendar.date(byAdding: .day, value: -(weeks * 7 - 1), to: gridEnd) else {
            return []
        }
        return (0..<(weeks * 7)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func level(for day: Date) -> Double {
        guard let xp = activity[calendar.startOfDay(for: day)], xp > 0 else { return 0 }
        return min(1, Double(xp) / Double(dailyGoal))
    }

    public var body: some View {
        let allDays = days
        let columns = stride(from: 0, to: allDays.count, by: 7).map { Array(allDays[$0..<min($0 + 7, allDays.count)]) }

        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                        VStack(spacing: 3) {
                            ForEach(week, id: \.self) { day in
                                cell(for: day)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack(spacing: DS.Spacing.xxs) {
                Text("Меньше")
                    .font(.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)
                ForEach([0.0, 0.35, 0.7, 1.0], id: \.self) { value in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fill(for: value))
                        .frame(width: 12, height: 12)
                }
                Text("Больше")
                    .font(.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Календарь занятий за \(weeks) недель")
        .accessibilityValue("Дней с занятиями: \(activity.values.filter { $0 > 0 }.count)")
    }

    @ViewBuilder
    private func cell(for day: Date) -> some View {
        let isFuture = calendar.startOfDay(for: day) > calendar.startOfDay(for: today)
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(isFuture ? Color.clear : fill(for: level(for: day)))
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(
                        calendar.isDate(day, inSameDayAs: today) ? DS.Colors.primary : .clear,
                        lineWidth: 1.5
                    )
            )
    }

    private func fill(for level: Double) -> Color {
        guard level > 0 else { return DS.Colors.border.opacity(0.55) }
        // Один оттенок разной плотности читается лучше, чем радуга.
        return DS.Colors.success.opacity(0.25 + 0.75 * level)
    }
}
