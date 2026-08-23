import SwiftUI
import Core
import ContentModels
import Persistence
import UIComponents

/// Дерево навыков в виде тропы: узлы идут сверху вниз со смещением в стороны,
/// соединённые линией. Пройденный участок пути закрашен, будущий — пунктиром,
/// поэтому прогресс виден одним взглядом, без чтения подписей.
struct SkillPathView: View {

    let skills: [SkillContent]
    let nodes: [String: SkillNode]
    let onSelect: (SkillContent) -> Void

    /// Насколько узлы уходят вбок. Больше — извилистее, но подписи начинают наезжать.
    private let sway: CGFloat = 58

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(skills.enumerated()), id: \.element.id) { index, skill in
                if index > 0 {
                    connector(above: skill, previous: skills[index - 1])
                }
                SkillPathNode(
                    skill: skill,
                    node: nodes[skill.skillKey],
                    prerequisiteTitle: prerequisiteTitle(for: skill),
                    onTap: { onSelect(skill) }
                )
                .offset(x: offset(for: index))
            }
        }
        .padding(.vertical, DS.Spacing.sm)
        .frame(maxWidth: .infinity)
    }

    /// Название навыка-предпосылки — подпись под закрытым узлом
    /// должна объяснять, что открывать, человеческим языком, а не ключом.
    private func prerequisiteTitle(for skill: SkillContent) -> String? {
        guard let key = skill.prerequisiteKeys.first else { return nil }
        return skills.first { $0.skillKey == key }?.title
    }

    /// Смещение по синусоиде: 0 → вправо → 0 → влево и снова.
    private func offset(for index: Int) -> CGFloat {
        switch index % 4 {
        case 1: return sway
        case 3: return -sway
        default: return 0
        }
    }

    /// Отрезок пути между двумя узлами.
    private func connector(above skill: SkillContent, previous: SkillContent) -> some View {
        let isPassed = (nodes[previous.skillKey]?.masteryLevel ?? 0) >= 1
        let isOpen = nodes[skill.skillKey]?.isUnlocked ?? false

        return Rectangle()
            .fill(.clear)
            .frame(width: 4, height: 36)
            .overlay(
                Capsule()
                    .strokeBorder(
                        isPassed || isOpen ? DS.Colors.success : DS.Colors.border,
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            dash: isPassed ? [] : [5, 6]
                        )
                    )
            )
            .accessibilityHidden(true)
    }
}

/// Один узел тропы: круг с иконкой, короны и подпись.
struct SkillPathNode: View {

    let skill: SkillContent
    let node: SkillNode?
    let prerequisiteTitle: String?
    let onTap: () -> Void

    private var isUnlocked: Bool { node?.isUnlocked ?? false }
    private var mastery: Int { node?.masteryLevel ?? 0 }
    private var completed: Int {
        node?.lessons.filter { $0.lessonStatus == .completed }.count ?? 0
    }
    private var total: Int { skill.lessons.count }
    private var isMastered: Bool { mastery >= GameRules.maxMasteryLevel }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                circle
                labels
            }
            .frame(width: 190)
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint(isUnlocked ? "Открыть навык" : "Навык закрыт")
    }

    private var circle: some View {
        ZStack {
            // Кольцо прогресса по урокам вокруг узла.
            Circle()
                .stroke(DS.Colors.border, lineWidth: 5)
            Circle()
                .trim(from: 0, to: total > 0 ? Double(completed) / Double(total) : 0)
                .stroke(DS.Colors.success, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(isUnlocked ? DS.Colors.category(skill.category.rawValue) : DS.Colors.border)
                .padding(7)

            Image(systemName: isUnlocked ? skill.iconName : "lock.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)

            if isMastered {
                // Освоенный навык помечается короной поверх узла.
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundStyle(DS.Colors.coin)
                    .padding(5)
                    .background(Circle().fill(DS.Colors.surface))
                    .offset(x: 26, y: -26)
            }
        }
        .frame(width: DS.Size.skillNode + 12, height: DS.Size.skillNode + 12)
        .animation(DS.Motion.standard, value: completed)
    }

    private var labels: some View {
        VStack(spacing: 2) {
            Text(skill.title)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(isUnlocked ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if isUnlocked {
                HStack(spacing: 2) {
                    ForEach(0..<GameRules.maxMasteryLevel, id: \.self) { index in
                        Image(systemName: index < mastery ? "crown.fill" : "crown")
                            .font(.system(size: 9))
                            .foregroundStyle(index < mastery ? DS.Colors.coin : DS.Colors.border)
                    }
                    Text("\(completed)/\(total)")
                        .font(.caption2)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .monospacedDigit()
                        .padding(.leading, 2)
                }
            } else {
                Text(lockedReason)
                    .font(.caption2)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var lockedReason: String {
        guard let prerequisiteTitle else { return "Скоро" }
        return "Освойте «\(prerequisiteTitle)»"
    }

    private var accessibilityText: String {
        guard isUnlocked else { return "\(skill.title), закрыт" }
        let crowns = mastery > 0 ? ", корон \(mastery)" : ""
        return "\(skill.title), пройдено \(completed) из \(total) уроков\(crowns)"
    }
}
