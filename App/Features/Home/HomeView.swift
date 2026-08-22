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

        return VStack(spacing: DS.Spacing.md) {
            ForEach(catalog.skills) { skill in
                SkillTreeRow(
                    skill: skill,
                    node: nodes[skill.skillKey],
                    completedLessons: completedCount(skill: skill, node: nodes[skill.skillKey]),
                    onTap: {
                        guard nodes[skill.skillKey]?.isUnlocked == true else {
                            Haptics.error()
                            return
                        }
                        coordinator.push(.skillDetail(skillKey: skill.skillKey))
                    }
                )
            }
        }
    }

    private func completedCount(skill: SkillContent, node: SkillNode?) -> Int {
        guard let node else { return 0 }
        return node.lessons.filter { $0.lessonStatus == .completed }.count
    }
}

/// Узел дерева: иконка навыка, короны освоения, прогресс по урокам.
struct SkillTreeRow: View {
    let skill: SkillContent
    let node: SkillNode?
    let completedLessons: Int
    let onTap: () -> Void

    private var isUnlocked: Bool { node?.isUnlocked ?? false }
    private var mastery: Int { node?.masteryLevel ?? 0 }
    private var totalLessons: Int { skill.lessons.count }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                nodeCircle

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(skill.title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(DS.Colors.textPrimary)

                    if let subtitle = skill.subtitle {
                        Text(subtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: DS.Spacing.xxs) {
                        ForEach(0..<GameRules.maxMasteryLevel, id: \.self) { index in
                            Image(systemName: index < mastery ? "crown.fill" : "crown")
                                .font(.caption2)
                                .foregroundStyle(index < mastery ? DS.Colors.coin : DS.Colors.border)
                        }
                        Text("· \(completedLessons)/\(totalLessons) уроков")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                Image(systemName: isUnlocked ? "chevron.right" : "lock.fill")
                    .foregroundStyle(DS.Colors.textSecondary)
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
            .opacity(isUnlocked ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isUnlocked ? "Открыть навык" : "Навык закрыт")
    }

    private var nodeCircle: some View {
        ZStack {
            Circle()
                .fill(isUnlocked ? DS.Colors.category(skill.category.rawValue) : DS.Colors.border)
            Image(systemName: isUnlocked ? skill.iconName : "lock.fill")
                .font(.system(size: DS.Size.skillNode * 0.36, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: DS.Size.skillNode, height: DS.Size.skillNode)
    }

    private var accessibilityText: String {
        let masteryText = mastery > 0 ? ", корон: \(mastery)" : ""
        return "\(skill.title), пройдено \(completedLessons) из \(totalLessons) уроков\(masteryText)"
    }
}
