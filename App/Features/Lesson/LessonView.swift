import SwiftUI
import Core
import ContentModels
import LessonEngine
import Persistence
import UIComponents

/// Экран прохождения урока: прогресс, задание, обратная связь.
struct LessonView: View {

    let lessonId: String
    let skillKey: String

    @Environment(GameStore.self) private var store
    @Environment(ContentCatalog.self) private var catalog
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss

    @State private var session: LessonSession?
    @State private var draftText = ""
    @State private var selectedOption: String?
    /// Собранное предложение в задании word_order.
    @State private var draftTokens: [String] = []
    @State private var showQuitConfirmation = false

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            if let session {
                content(session: session)
            } else {
                ContentUnavailableView(
                    "Урок недоступен",
                    systemImage: "exclamationmark.triangle",
                    description: Text("Контент урока не найден или не содержит заданий.")
                )
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .onAppear { startSessionIfNeeded() }
        .confirmationDialog(
            "Выйти из урока? Прогресс этого прохождения не сохранится.",
            isPresented: $showQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Выйти", role: .destructive) {
                // Потраченные сердца записываем и при досрочном выходе,
                // иначе ошибку можно было бы «отменить», закрыв урок.
                if let session { persistHearts(session) }
                dismiss()
            }
            Button("Остаться", role: .cancel) {}
        }
    }

    // MARK: - Содержимое

    @ViewBuilder
    private func content(session: LessonSession) -> some View {
        switch session.phase {
        case .finished(let summary):
            LessonCompleteView(summary: summary) {
                coordinator.popToRoot()
            } onRetry: {
                restartSession()
            }
        case .outOfHearts:
            OutOfHeartsView(
                onRefill: {
                    guard store.purchaseHeartRefill() else { return }
                    session.refillHearts()
                },
                onExit: {
                    session.abandon()
                    // Даже проваленный урок записывает попытку и ошибки —
                    // они нужны для разбора и будущей адаптивности.
                    if case .finished(let summary) = session.phase {
                        store.apply(summary: summary)
                    }
                }
            )
        case .question, .feedback:
            questionLayout(session: session)
        }
    }

    private func questionLayout(session: LessonSession) -> some View {
        VStack(spacing: 0) {
            if let exercise = session.currentExercise {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        prompt(for: exercise)
                        exerciseBody(exercise: exercise, session: session)
                            // Новый шаг урока — новое состояние вью. В идентичность входит
                            // позиция в очереди, а не только id: проваленное задание
                            // встречается повторно и должно начинаться с чистого листа.
                            .id("\(exercise.id)#\(session.currentPosition)")
                        if let hint = exercise.hint, session.hintRevealed {
                            hintView(hint)
                        }
                    }
                    .padding(DS.Spacing.md)
                }

                Spacer(minLength: 0)

                footer(exercise: exercise, session: session)
            }
        }
    }

    private func prompt(for exercise: Exercise) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // В fill_blank само предложение рисует вью задания — здесь только инструкция,
            // иначе текст с пропуском показывался бы дважды.
            Text(exercise.type == .fillBlank ? "Вставьте пропущенное слово" : exercise.prompt)
                .font(exercise.type == .fillBlank ? DS.Typography.callout : DS.Typography.exercisePrompt)
                .foregroundStyle(exercise.type == .fillBlank ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let translation = exercise.promptTranslation {
                Text(translation)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func exerciseBody(exercise: Exercise, session: LessonSession) -> some View {
        switch exercise.type {
        case .multipleChoice, .listening:
            MultipleChoiceExerciseView(
                exercise: exercise,
                selected: $selectedOption,
                isLocked: isFeedbackVisible(session),
                correctAnswer: revealedAnswer(session)
            )
        case .typeAnswer, .speaking:
            TypeAnswerExerciseView(
                text: $draftText,
                isLocked: isFeedbackVisible(session)
            )
        case .matchPairs:
            MatchPairsExerciseView(
                exercise: exercise,
                matchedPairIds: session.matchedPairIds,
                onSelectPair: { pairId, right in
                    // У match_pairs фаза между парами не меняется, поэтому отклик
                    // берём прямо из результата, а не из phase.
                    let feedback = session.submit(.pairMatch(pairId: pairId, right: right))
                    if feedback.awaitingMorePairs {
                        // Задание ещё идёт: отклик даём здесь, фаза не менялась.
                        if feedback.verdict == .incorrect {
                            Haptics.error()
                        } else {
                            Haptics.light()
                        }
                    } else {
                        // Последняя пара закрыла задание — отклик даст reactToPhase.
                        reactToPhase(session)
                    }
                }
            )
        case .wordOrder:
            WordOrderExerciseView(
                exercise: exercise,
                chosen: $draftTokens,
                isLocked: isFeedbackVisible(session)
            )
        case .fillBlank:
            FillBlankExerciseView(
                exercise: exercise,
                text: $draftText,
                selected: $selectedOption,
                isLocked: isFeedbackVisible(session),
                correctAnswer: revealedAnswer(session)
            )
        }
    }

    private func hintView(_ hint: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.xs) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(DS.Colors.warning)
            Text(hint)
                .font(DS.Typography.callout)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }

    // MARK: - Нижняя панель

    @ViewBuilder
    private func footer(exercise: Exercise, session: LessonSession) -> some View {
        if case .feedback(let feedback) = session.phase {
            FeedbackBanner(
                style: bannerStyle(for: feedback.verdict),
                correctAnswer: feedback.verdict == .correct ? nil : feedback.correctAnswer,
                explanation: feedback.explanation
            ) {
                session.advance()
                resetInputs()
                persistHearts(session)
                if case .finished(let summary) = session.phase {
                    store.apply(summary: summary)
                }
            }
        } else {
            VStack(spacing: DS.Spacing.xs) {
                if exercise.hint != nil && !session.hintRevealed && exercise.type != .matchPairs {
                    Button {
                        session.revealHint()
                    } label: {
                        Label("Подсказка", systemImage: "lightbulb")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }

                if exercise.type != .matchPairs {
                    ActionButton("Проверить", isEnabled: canSubmit(exercise: exercise)) {
                        submit(exercise: exercise, session: session)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showQuitConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .accessibilityLabel("Выйти из урока")
        }
        ToolbarItem(placement: .principal) {
            LessonProgressBar(progress: session?.progress ?? 0)
                .frame(width: 160)
        }
        ToolbarItem(placement: .topBarTrailing) {
            HeartsIndicator(count: session?.heartsLeft ?? store.hearts.current())
        }
    }

    // MARK: - Логика

    private func startSessionIfNeeded() {
        guard session == nil else { return }
        guard let lesson = catalog.lesson(id: lessonId) else { return }
        session = LessonSession(lesson: lesson, skillKey: skillKey, hearts: store.hearts)
    }

    private func restartSession() {
        guard let lesson = catalog.lesson(id: lessonId) else { return }
        resetInputs()
        session = LessonSession(lesson: lesson, skillKey: skillKey, hearts: store.hearts)
    }

    private func submit(exercise: Exercise, session: LessonSession) {
        let input: AnswerInput
        switch exercise.type {
        case .multipleChoice, .listening:
            guard let selectedOption else { return }
            input = .choice(selectedOption)
        case .typeAnswer, .speaking:
            input = .text(draftText)
        case .fillBlank:
            // Пропуск заполняется либо выбором варианта, либо вводом слова.
            if let selectedOption {
                input = .choice(selectedOption)
            } else {
                input = .text(draftText)
            }
        case .wordOrder:
            input = .tokens(draftTokens)
        }

        _ = session.submit(input)
        reactToPhase(session)
    }

    private func reactToPhase(_ session: LessonSession) {
        switch session.phase {
        case .feedback(let feedback):
            feedback.verdict == .incorrect ? Haptics.error() : Haptics.success()
        case .outOfHearts:
            Haptics.error()
            persistHearts(session)
        default:
            break
        }
    }

    private func persistHearts(_ session: LessonSession) {
        store.persist(hearts: session.hearts)
    }

    private func resetInputs() {
        draftText = ""
        selectedOption = nil
        draftTokens = []
    }

    private func canSubmit(exercise: Exercise) -> Bool {
        switch exercise.type {
        case .multipleChoice, .listening:
            return selectedOption != nil
        case .typeAnswer, .speaking:
            return !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .fillBlank:
            return selectedOption != nil || !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .wordOrder:
            return !draftTokens.isEmpty
        case .matchPairs:
            return false
        }
    }

    private func isFeedbackVisible(_ session: LessonSession) -> Bool {
        if case .feedback = session.phase { return true }
        return false
    }

    private func revealedAnswer(_ session: LessonSession) -> String? {
        if case .feedback(let feedback) = session.phase {
            return feedback.correctAnswer ?? session.currentExercise?.correctAnswer
        }
        return nil
    }

    private func bannerStyle(for verdict: AnswerVerdict) -> FeedbackBanner.Style {
        switch verdict {
        case .correct: return .correct
        case .almost: return .almost
        case .incorrect: return .incorrect
        }
    }
}
