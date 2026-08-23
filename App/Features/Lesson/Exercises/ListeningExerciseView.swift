import SwiftUI
import Core
import ContentModels
import SpeechKit
import UIComponents

/// Задание на слух: фраза звучит, текст скрыт, ответ выбирается из вариантов.
/// Повторное прослушивание доступно всегда, замедленное — тоже: на A1
/// разобрать беглую речь с первого раза почти невозможно.
struct ListeningExerciseView: View {

    let exercise: Exercise
    @Binding var selected: String?
    let isLocked: Bool
    let correctAnswer: String?

    @Environment(SpeechPlayer.self) private var player

    /// Что произносить: явный audioText, иначе правильный ответ.
    private var spokenText: String {
        exercise.audioText ?? exercise.correctAnswer ?? ""
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            listenControls

            VStack(spacing: DS.Spacing.sm) {
                ForEach(exercise.options ?? [], id: \.self) { option in
                    ChoiceCard(text: option, state: state(for: option)) {
                        guard !isLocked else { return }
                        selected = option
                    }
                    .disabled(isLocked)
                }
            }

            if isLocked {
                // После проверки текст можно показать — теперь он учит, а не подсказывает.
                Text(spokenText)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .onAppear { player.speak(spokenText) }
        .onChange(of: exercise.id) { _, _ in player.speak(spokenText) }
    }

    private var listenControls: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button {
                player.speak(spokenText)
            } label: {
                ZStack {
                    Circle()
                        .fill(DS.Colors.primary)
                    Image(systemName: player.isSpeaking ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 96, height: 96)
                .scaleEffect(player.isSpeaking ? 1.06 : 1)
                .animation(DS.Motion.bouncy, value: player.isSpeaking)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Прослушать фразу")

            Button {
                player.speak(spokenText, slow: true)
            } label: {
                Label("Медленнее", systemImage: "tortoise.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .accessibilityLabel("Прослушать медленно")
        }
        .frame(maxWidth: .infinity)
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
