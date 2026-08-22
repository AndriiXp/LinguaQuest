import SwiftUI
import Core
import ContentModels
import Persistence
import UIComponents

/// Список уроков внутри навыка.
struct SkillDetailView: View {

    let skillKey: String

    @Environment(GameStore.self) private var store
    @Environment(ContentCatalog.self) private var catalog
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Group {
            if let skill = catalog.skill(for: skillKey) {
                content(for: skill)
            } else {
                ContentUnavailableView(
                    "Навык не найден",
                    systemImage: "questionmark.folder",
                    description: Text("Контент этого навыка отсутствует в текущей версии приложения.")
                )
            }
        }
        .background(DS.Colors.background)
        .navigationTitle(catalog.skill(for: skillKey)?.title ?? "Навык")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for skill: SkillContent) -> some View {
        let node = store.skillNode(for: skillKey)
        let progressByLesson = Dictionary(
            (node?.lessons ?? []).map { ($0.lessonId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return ScrollView {
            VStack(spacing: DS.Spacing.md) {
                header(skill: skill, node: node)

                ForEach(skill.orderedLessons) { lesson in
                    LessonRow(
                        lesson: lesson,
                        progress: progressByLesson[lesson.lessonId],
                        onTap: {
                            coordinator.push(.lesson(lessonId: lesson.lessonId, skillKey: skillKey))
                        }
                    )
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    private func header(skill: SkillContent, node: SkillNode?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xxs) {
                ForEach(0..<GameRules.maxMasteryLevel, id: \.self) { index in
                    Image(systemName: index < (node?.masteryLevel ?? 0) ? "crown.fill" : "crown")
                        .foregroundStyle(index < (node?.masteryLevel ?? 0) ? DS.Colors.coin : DS.Colors.border)
                }
            }
            if let subtitle = skill.subtitle {
                Text(subtitle)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            if let source = skill.sourceStandard {
                Text("Материал построен на: \(source)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.top, DS.Spacing.xxs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }
}

/// Строка урока: статус, лучший результат, награда.
struct LessonRow: View {
    let lesson: LessonContent
    let progress: LessonProgress?
    let onTap: () -> Void

    private var status: LessonStatus { progress?.lessonStatus ?? .locked }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .font(.title3)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text(subtitle)
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                StatChip(kind: .xp, value: lesson.xpReward)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(status == .locked ? DS.Colors.border : statusColor.opacity(0.35), lineWidth: 1)
            )
            .opacity(status == .locked ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(status == .locked)
        .accessibilityLabel("\(lesson.title), \(accessibilityStatus)")
    }

    private var subtitle: String {
        switch status {
        case .locked:
            return "Пройдите предыдущий урок"
        case .available:
            return (progress?.attemptsCount ?? 0) > 0
                ? "Лучший результат: \(progress?.bestScore ?? 0)%"
                : "\(lesson.exercises.count) заданий"
        case .completed:
            return "Пройден · \(progress?.bestScore ?? 0)%"
        }
    }

    private var statusColor: Color {
        switch status {
        case .locked: return DS.Colors.textSecondary
        case .available: return DS.Colors.primary
        case .completed: return DS.Colors.success
        }
    }

    private var statusIcon: String {
        switch status {
        case .locked: return "lock.fill"
        case .available: return "play.fill"
        case .completed: return "checkmark"
        }
    }

    private var accessibilityStatus: String {
        switch status {
        case .locked: return "закрыт"
        case .available: return "доступен"
        case .completed: return "пройден"
        }
    }
}
