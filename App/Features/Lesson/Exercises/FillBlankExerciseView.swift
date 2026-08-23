import SwiftUI
import Core
import ContentModels
import UIComponents

/// Задание с пропуском. Предложение показывается целиком, на месте маркера `___`
/// стоит поле для ответа — так видно контекст, а не голый вопрос.
///
/// Если у задания есть варианты ответа, они показываются кнопками;
/// иначе слово вводится с клавиатуры.
struct FillBlankExerciseView: View {

    let exercise: Exercise
    @Binding var text: String
    @Binding var selected: String?
    let isLocked: Bool
    let correctAnswer: String?

    @FocusState private var isFocused: Bool

    private var hasOptions: Bool { (exercise.options?.count ?? 0) >= 2 }

    /// Текст до и после пропуска.
    private var parts: (before: String, after: String) {
        let pieces = exercise.prompt.components(separatedBy: "___")
        return (pieces.first ?? exercise.prompt, pieces.count > 1 ? pieces[1] : "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            sentence
            if hasOptions {
                options
            } else {
                input
            }
        }
    }

    // MARK: - Предложение с пропуском

    private var sentence: some View {
        let filled = hasOptions ? selected : (text.isEmpty ? nil : text)

        return FlowLayout(spacing: 6) {
            ForEach(Array(parts.before.split(separator: " ").enumerated()), id: \.offset) { _, word in
                Text(String(word))
                    .font(DS.Typography.exercisePrompt)
                    .foregroundStyle(DS.Colors.textPrimary)
            }

            Text(filled ?? "＿＿＿")
                .font(DS.Typography.exercisePrompt)
                .foregroundStyle(filled == nil ? DS.Colors.textSecondary : DS.Colors.primary)
                .padding(.horizontal, DS.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                        .fill(DS.Colors.primarySoft.opacity(filled == nil ? 0.6 : 1))
                )

            ForEach(Array(parts.after.split(separator: " ").enumerated()), id: \.offset) { _, word in
                Text(String(word))
                    .font(DS.Typography.exercisePrompt)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Предложение с пропуском: \(parts.before) пропуск \(parts.after)")
        .accessibilityValue(filled ?? "не заполнено")
    }

    // MARK: - Варианты

    private var options: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(exercise.options ?? [], id: \.self) { option in
                ChoiceCard(text: option, state: state(for: option)) {
                    guard !isLocked else { return }
                    selected = option
                }
                .disabled(isLocked)
            }
        }
    }

    private func state(for option: String) -> ChoiceState {
        guard isLocked else {
            return selected == option ? .selected : .idle
        }
        if let correctAnswer, option == correctAnswer { return .correct }
        if selected == option { return .incorrect }
        return .idle
    }

    // MARK: - Ввод текстом

    private var input: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            TextField("Пропущенное слово", text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Colors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(isFocused ? DS.Colors.primary : DS.Colors.border, lineWidth: isFocused ? 2 : 1)
                )
                .focused($isFocused)
                .disabled(isLocked)

            Text("Одно слово в нужной форме")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .animation(DS.Motion.quick, value: isFocused)
        .onAppear { isFocused = true }
        .onChange(of: isLocked) { _, locked in
            if locked { isFocused = false }
        }
    }
}
