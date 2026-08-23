import SwiftUI
import Core
import ContentModels
import Persistence
import UIComponents

/// Профиль игрока: аватар, уровень, ключевая статистика.
struct ProfileView: View {

    @Environment(GameStore.self) private var store
    @Environment(ContentCatalog.self) private var catalog
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                avatarHeader
                statsGrid
                activitySection
                achievementsSection
                skillSummary
            }
            .padding(DS.Spacing.md)
        }
        .background(DS.Colors.background)
        .navigationTitle("Профиль")
        .onAppear { store.refreshDueCardsCount() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    coordinator.push(.settings)
                } label: {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Настройки")
            }
        }
    }

    private var avatarHeader: some View {
        let profile = store.profile
        let avatar = AvatarCatalog.item(id: profile.selectedAvatarId) ?? AvatarCatalog.all[0]

        return VStack(spacing: DS.Spacing.sm) {
            Button {
                coordinator.push(.avatarGallery)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    AvatarBadge(avatar: avatar, size: 108)
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(DS.Colors.primary)
                        .background(Circle().fill(DS.Colors.surface))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Сменить аватар")

            Text(profile.displayName)
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.textPrimary)

            Text("Уровень \(profile.level) · \(profile.currentCEFR)")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)

            LevelProgressView(
                level: profile.level,
                progress: Progression.levelProgress(totalXP: profile.xpTotal),
                xpInLevel: Progression.xpInCurrentLevel(totalXP: profile.xpTotal),
                xpNeeded: Progression.xpNeededForNextLevel(totalXP: profile.xpTotal)
            )
            .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }

    private var statsGrid: some View {
        let profile = store.profile
        let cards = store.dueCardsCount

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DS.Spacing.sm) {
            statTile(title: "Серия дней", value: "\(profile.streakCount)", symbol: "flame.fill", tint: DS.Colors.streak)
            statTile(title: "Всего опыта", value: "\(profile.xpTotal)", symbol: "bolt.fill", tint: DS.Colors.xp)
            statTile(title: "Монеты", value: "\(profile.coins)", symbol: "circle.hexagongrid.fill", tint: DS.Colors.coin)
            statTile(title: "К повторению", value: "\(cards)", symbol: "rectangle.stack.fill", tint: DS.Colors.primary)
        }
    }

    private func statTile(title: String, value: String, symbol: String, tint: Color) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(title)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Календарь занятий")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Text("\(activeDays) \(dayWord(activeDays))")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            ActivityCalendar(activity: activity, dailyGoal: store.profile.dailyGoalXP)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }

    private var achievementsSection: some View {
        let items = store.achievements()
        let unlocked = items.filter { $0.record?.isUnlocked == true }.count

        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Достижения")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Text("\(unlocked) из \(items.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: DS.Spacing.sm)], spacing: DS.Spacing.md) {
                ForEach(items, id: \.definition.id) { item in
                    AchievementBadge(
                        definition: item.definition,
                        progress: item.record?.progress ?? 0,
                        isUnlocked: item.record?.isUnlocked ?? false
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }

    private var activity: [Date: Int] {
        store.activityMap()
    }

    private var activeDays: Int {
        activity.values.filter { $0 > 0 }.count
    }

    private func dayWord(_ count: Int) -> String {
        let hundred = count % 100
        let ten = count % 10
        if (11...14).contains(hundred) { return "дней" }
        switch ten {
        case 1: return "день"
        case 2, 3, 4: return "дня"
        default: return "дней"
        }
    }

    private var skillSummary: some View {
        let nodes = store.allSkillNodes()
        let crowns = nodes.reduce(0) { $0 + $1.masteryLevel }
        let completed = nodes.reduce(0) { $0 + $1.lessons.filter { $0.lessonStatus == .completed }.count }

        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Прогресс обучения")
                .font(DS.Typography.headline)
                .foregroundStyle(DS.Colors.textPrimary)
            Text("Пройдено уроков: \(completed)")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)
            Text("Корон получено: \(crowns)")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)
            Text("Навыков открыто: \(nodes.filter(\.isUnlocked).count) из \(catalog.skills.count)")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }
}
