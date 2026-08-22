import SwiftUI
import Core

/// Задание с вводом ответа текстом.
struct TypeAnswerExerciseView: View {

    @Binding var text: String
    let isLocked: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            TextField("Ваш ответ", text: $text, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.done)
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
                .accessibilityLabel("Поле ответа")

            Text("Регистр и знаки препинания не важны")
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
