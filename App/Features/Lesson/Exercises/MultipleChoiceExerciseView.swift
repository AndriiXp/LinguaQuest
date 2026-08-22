import SwiftUI
import Core
import ContentModels
import UIComponents

/// Задание с выбором одного варианта.
struct MultipleChoiceExerciseView: View {

    let exercise: Exercise
    @Binding var selected: String?
    /// После проверки выбор блокируется, чтобы ответ нельзя было «переиграть».
    let isLocked: Bool
    /// Правильный ответ подсвечивается зелёным после проверки.
    let correctAnswer: String?

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(exercise.options ?? [], id: \.self) { option in
                ChoiceCard(text: option, state: state(for: option)) {
                    guard !isLocked else { return }
                    selected = option
                }
                .disabled(isLocked)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func state(for option: String) -> ChoiceState {
        guard isLocked else {
            return selected == option ? .selected : .idle
        }
        if let correctAnswer, option == correctAnswer { return .correct }
        if selected == option { return .incorrect }
        return .idle
    }
}
