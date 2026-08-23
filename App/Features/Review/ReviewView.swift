import SwiftUI
import Core
import ContentModels
import SRSEngine
import Persistence
import UIComponents

/// Экран повторения: карточка со словом, самооценка, пересчёт расписания.
struct ReviewView: View {

    @Environment(GameStore.self) private var store
    @Environment(ContentCatalog.self) private var catalog

    @State private var session: ReviewSession?
    @State private var showTranslationFirst = false

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            if let session {
                content(session: session)
            } else {
                emptyState
            }
        }
        .navigationTitle("Повторение")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.refreshDueCardsCount() }
    }

    // MARK: - Состояния экрана

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: store.dueCardsCount > 0 ? "rectangle.stack.fill" : "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(store.dueCardsCount > 0 ? DS.Colors.primary : DS.Colors.success)

            Text(store.dueCardsCount > 0 ? "К повторению: \(store.dueCardsCount)" : "На сегодня всё")
                .font(DS.Typography.title)
                .foregroundStyle(DS.Colors.textPrimary)

            Text(store.dueCardsCount > 0
                 ? "Слова из пройденных уроков ждут повторения. Это занимает пару минут."
                 : "Карточки появятся после новых уроков или когда подойдёт срок повторения.")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)

            if store.dueCardsCount > 0 {
                ActionButton("Начать повторение", icon: "play.fill") {
                    start()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.xs)
            }
        }
    }

    @ViewBuilder
    private func content(session: ReviewSession) -> some View {
        switch session.phase {
        case .finished(let summary):
            ReviewCompleteView(summary: summary) {
                self.session = nil
                store.refreshDueCardsCount()
            }
        case .recalling, .revealed:
            cardLayout(session: session)
        }
    }

    // MARK: - Карточка

    private func cardLayout(session: ReviewSession) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.sm) {
                LessonProgressBar(progress: session.progress)
                Text("\(session.completedCount) / \(session.totalCount)")
                    .font(DS.Typography.counter)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .padding(DS.Spacing.md)

            Spacer(minLength: 0)

            if let item = session.currentItem {
                card(item: item, isRevealed: session.phase == .revealed)
                    .padding(.horizontal, DS.Spacing.md)
                    .id(item.id)
            }

            Spacer(minLength: 0)

            footer(session: session)
        }
    }

    private func card(item: ReviewItem, isRevealed: Bool) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Text(showTranslationFirst ? item.translation : item.word)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)

            if isRevealed {
                Divider()
                    .padding(.horizontal, DS.Spacing.xl)

                Text(showTranslationFirst ? item.word : item.translation)
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.primary)
                    .multilineTextAlignment(.center)

                if let example = item.example {
                    Text(example)
                        .font(DS.Typography.callout)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, DS.Spacing.xxs)
                }
            } else {
                Text("Вспомните перевод")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .fill(DS.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                .strokeBorder(DS.Colors.border, lineWidth: 1)
        )
        .animation(DS.Motion.standard, value: isRevealed)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func footer(session: ReviewSession) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            if session.phase == .revealed {
                Text("Насколько легко вспомнилось?")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)

                HStack(spacing: DS.Spacing.xs) {
                    ratingButton(.forgot, role: .danger, session: session)
                    ratingButton(.hard, role: .secondary, session: session)
                    ratingButton(.easy, role: .success, session: session)
                }
            } else {
                ActionButton("Показать перевод") {
                    session.reveal()
                }
            }
        }
        .padding(DS.Spacing.md)
    }

    private func ratingButton(_ rating: RecallRating, role: ActionButtonRole, session: ReviewSession) -> some View {
        ActionButton(rating.title, role: role) {
            // Оценка «не помню» ощущается как ошибка — отклик соответствующий.
            if rating == .forgot {
                Haptics.error()
            } else {
                Haptics.success()
            }
            session.rate(rating)
            applyIfFinished(session)
        }
    }

    // MARK: - Логика

    private func start() {
        let cards = store.dueCards()
        let items = cards.map { card in
            ReviewItem(
                id: card.itemId,
                word: card.word,
                translation: card.translation,
                example: catalog.vocabulary(id: card.itemId)?.exampleSentence,
                state: card.state
            )
        }
        guard !items.isEmpty else { return }
        // Направление показа меняется от сессии к сессии: узнавать слово
        // и вспоминать его — разные навыки, тренировать нужно оба.
        showTranslationFirst = Bool.random()
        session = ReviewSession(items: items)
    }

    private func applyIfFinished(_ session: ReviewSession) {
        guard case .finished(let summary) = session.phase else { return }
        store.applyReview(summary: summary)
    }
}

/// Итоги сессии повторения.
struct ReviewCompleteView: View {
    let summary: ReviewSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()

            ZStack {
                Circle()
                    .fill(DS.Colors.success.opacity(0.15))
                    .frame(width: 112, height: 112)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(DS.Colors.success)
            }

            Text("Повторение завершено")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(DS.Colors.textPrimary)

            Text("Вспомнили \(summary.remembered) из \(summary.total) · \(summary.accuracyPercent)%")
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)

            if summary.forgotten > 0 {
                Text("\(summary.forgotten) \(cardWord(summary.forgotten)) вернутся завтра")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            Spacer()

            ActionButton("Готово", role: .success, action: onDone)
                .padding(DS.Spacing.md)
        }
    }

    private func cardWord(_ count: Int) -> String {
        let hundred = count % 100
        let ten = count % 10
        if (11...14).contains(hundred) { return "карточек" }
        switch ten {
        case 1: return "карточка"
        case 2, 3, 4: return "карточки"
        default: return "карточек"
        }
    }
}
