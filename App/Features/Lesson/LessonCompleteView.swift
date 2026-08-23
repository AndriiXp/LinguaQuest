import SwiftUI
import Core
import LessonEngine
import Persistence
import UIComponents

/// Итоговый экран урока: награды, точность и разбор ошибок.
struct LessonCompleteView: View {

    let summary: LessonSummary
    let onContinue: () -> Void
    let onRetry: () -> Void

    @Environment(GameStore.self) private var store
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                header
                rewards
                achievementsBanner
                if !summary.mistakes.isEmpty {
                    mistakesBreakdown
                }
                streakBanner
            }
            .padding(DS.Spacing.md)
            .padding(.bottom, 120)
        }
        .background(DS.Colors.background)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Spacing.xs) {
                ActionButton("Продолжить", role: .success, action: onContinue)
                if !summary.isPassed {
                    ActionButton("Пройти заново", role: .secondary, action: onRetry)
                }
            }
            .padding(DS.Spacing.md)
            .background(.ultraThinMaterial)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(DS.Motion.bouncy.delay(0.1)) { appeared = true }
            if summary.isPassed {
                Haptics.success()
            } else {
                Haptics.error()
            }
        }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 120, height: 120)
                Image(systemName: statusIcon)
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(statusColor)
            }
            .scaleEffect(appeared ? 1 : 0.6)

            Text(title)
                .font(DS.Typography.largeTitle)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(subtitle)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.lg)
    }

    private var title: String {
        if summary.ranOutOfHearts { return "Сердца закончились" }
        if summary.isPerfect { return "Безупречно!" }
        return summary.isPassed ? "Урок пройден" : "Почти получилось"
    }

    private var subtitle: String {
        "Верно с первой попытки: \(summary.correctFirstTry) из \(summary.totalExercises) · \(summary.scorePercent)%"
    }

    private var statusColor: Color {
        summary.isPassed ? DS.Colors.success : DS.Colors.warning
    }

    private var statusIcon: String {
        if summary.ranOutOfHearts { return "heart.slash.fill" }
        return summary.isPerfect ? "star.fill" : (summary.isPassed ? "checkmark" : "arrow.counterclockwise")
    }

    // MARK: - Награды

    private var rewards: some View {
        HStack(spacing: DS.Spacing.sm) {
            rewardTile(title: "Опыт", value: "+\(summary.xpEarned)", symbol: "bolt.fill", tint: DS.Colors.xp)
            rewardTile(title: "Монеты", value: "+\(summary.coinsEarned)", symbol: "circle.hexagongrid.fill", tint: DS.Colors.coin)
            rewardTile(title: "Точность", value: "\(summary.scorePercent)%", symbol: "target", tint: DS.Colors.primary)
        }
    }

    private func rewardTile(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: DS.Spacing.xxs) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
            Text(value)
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.textPrimary)
            Text(title)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    // MARK: - Новые достижения

    @ViewBuilder
    private var achievementsBanner: some View {
        let unlocked = store.newlyUnlockedAchievements
        if !unlocked.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text(unlocked.count == 1 ? "Новое достижение" : "Новые достижения")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)

                ForEach(unlocked) { achievement in
                    HStack(spacing: DS.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(DS.Colors.tint(achievement.tintKey).opacity(0.18))
                            Image(systemName: achievement.symbolName)
                                .foregroundStyle(DS.Colors.tint(achievement.tintKey))
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(achievement.title)
                                .font(DS.Typography.bodyBold)
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text(achievement.detail)
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .fill(DS.Colors.surface)
                    )
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Разбор ошибок

    private var mistakesBreakdown: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Разбор ошибок")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.textPrimary)

            ForEach(summary.mistakes) { mistake in
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(mistake.prompt)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.textPrimary)
                    HStack(spacing: DS.Spacing.xs) {
                        Label(mistake.userAnswer, systemImage: "xmark.circle.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.danger)
                        Label(mistake.correctAnswer, systemImage: "checkmark.circle.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.success)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Colors.surface)
                )
            }
        }
    }

    // MARK: - Streak

    @ViewBuilder
    private var streakBanner: some View {
        if case .extended(let value) = store.lastStreakEvent {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(DS.Colors.streak)
                VStack(alignment: .leading) {
                    Text("Серия: \(value) \(dayWord(value))")
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("Дневная цель выполнена")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(DS.Colors.streak.opacity(0.12))
            )
        }
    }

    private func dayWord(_ count: Int) -> String {
        let remainder100 = count % 100
        let remainder10 = count % 10
        if (11...14).contains(remainder100) { return "дней" }
        switch remainder10 {
        case 1: return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
        }
    }
}

/// Экран «сердца закончились».
struct OutOfHeartsView: View {
    let onRefill: () -> Void
    let onExit: () -> Void

    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(DS.Colors.heart)
            Text("Сердца закончились")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.textPrimary)
            Text("Сердце восстанавливается каждые \(GameRules.heartRegenMinutes) минут. Можно подождать или восстановить сразу.")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)

            VStack(spacing: DS.Spacing.xs) {
                ActionButton(
                    "Восстановить за \(GameRules.refillHeartsGemPrice) кристаллов",
                    icon: "diamond.fill",
                    isEnabled: store.profile.gems >= GameRules.refillHeartsGemPrice,
                    action: onRefill
                )
                ActionButton("Завершить урок", role: .secondary, action: onExit)
            }
            .padding(.horizontal, DS.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
    }
}

