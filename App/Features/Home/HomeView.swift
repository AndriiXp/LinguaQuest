import SwiftUI
import Core
import ContentModels
import Persistence
import UIComponents

/// Главный экран: шапка с игровыми счётчиками и дерево навыков.
struct HomeView: View {

    @Environment(GameStore.self) private var store
    @Environment(ContentCatalog.self) private var catalog
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                dailyGoalCard
                skillTree
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Colors.background)
        .navigationTitle("LinguaQuest")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                StatChip(kind: .streak, value: store.profile.streakCount)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                StatChip(kind: .coins, value: store.profile.coins)
                HeartsIndicator(count: store.hearts.current())
            }
        }
    }

    // MARK: - Дневная цель

    private var dailyGoalCard: some View {
        let profile = store.profile
        let goalProgress = profile.dailyGoalXP > 0
            ? Double(profile.todayXP) / Double(profile.dailyGoalXP)
            : 0

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Цель на сегодня")
                    .font(DS.Typography.headline)
                    .foregroundStyle(DS.Colors.textPrimary)
                Spacer()
                Text("\(profile.todayXP) / \(profile.dailyGoalXP) XP")
                    .font(DS.Typography.counter)
                    .foregroundStyle(goalProgress >= 1 ? DS.Colors.success : DS.Colors.textSecondary)
            }

            LessonProgressBar(progress: goalProgress)

            LevelProgressView(
                level: profile.level,
                progress: Progression.levelProgress(totalXP: profile.xpTotal),
                xpInLevel: Progression.xpInCurrentLevel(totalXP: profile.xpTotal),
                xpNeeded: Progression.xpNeededForNextLevel(totalXP: profile.xpTotal)
            )
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: - Дерево навыков

    private var skillTree: some View {
        let nodes = Dictionary(
            store.allSkillNodes().map { ($0.skillKey, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return SkillPathView(
            skills: catalog.skills,
            nodes: nodes,
            onSelect: { skill in
                coordinator.push(.skillDetail(skillKey: skill.skillKey))
            }
        )
    }
}
