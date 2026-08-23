import SwiftUI
import Core
import ContentModels
import SpeechKit
import UIComponents

/// Задание на произношение: фразу можно послушать, затем произнести самому.
/// Распознанный текст сравнивается с эталоном, оценка мягкая — распознавание
/// ошибается на акценте, и штрафовать за это несправедливо.
struct SpeakingExerciseView: View {

    let exercise: Exercise
    /// Распознанный текст уходит в движок урока как обычный ответ.
    @Binding var recognized: String
    let isLocked: Bool

    @Environment(SpeechPlayer.self) private var player
    @State private var recorder = SpeechRecorder()
    @State private var result: PronunciationResult?

    private var target: String {
        exercise.correctAnswer ?? exercise.audioText ?? exercise.prompt
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            phraseCard
            micControl

            if let error = recorder.error {
                Text(error.localizedDescription)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.danger)
                    .multilineTextAlignment(.center)
            } else if !recorder.transcript.isEmpty || !recognized.isEmpty {
                heardCard
            }
        }
        .onChange(of: recorder.transcript) { _, text in
            guard !text.isEmpty else { return }
            recognized = text
            result = PronunciationScorer.score(recognized: text, expected: target)
        }
        .onChange(of: exercise.id) { _, _ in
            recognized = ""
            result = nil
        }
        .onDisappear { recorder.stop() }
    }

    // MARK: - Фраза

    private var phraseCard: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(target)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Button {
                player.speak(target)
            } label: {
                Label("Послушать", systemImage: "speaker.wave.2.fill")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }

    // MARK: - Микрофон

    private var micControl: some View {
        VStack(spacing: DS.Spacing.xs) {
            Button {
                Task {
                    if recorder.isRecording {
                        recorder.stop()
                    } else {
                        recognized = ""
                        result = nil
                        await recorder.start()
                    }
                }
            } label: {
                ZStack {
                    // Кольцо реагирует на громкость — видно, что микрофон слышит.
                    Circle()
                        .fill(DS.Colors.danger.opacity(0.18))
                        .frame(width: 96 + CGFloat(recorder.level) * 40,
                               height: 96 + CGFloat(recorder.level) * 40)
                        .opacity(recorder.isRecording ? 1 : 0)

                    Circle()
                        .fill(recorder.isRecording ? DS.Colors.danger : DS.Colors.primary)
                        .frame(width: 88, height: 88)

                    Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .animation(DS.Motion.quick, value: recorder.level)
                .animation(DS.Motion.standard, value: recorder.isRecording)
            }
            .buttonStyle(.plain)
            .disabled(isLocked)
            .accessibilityLabel(recorder.isRecording ? "Остановить запись" : "Записать произношение")

            Text(recorder.isRecording ? "Говорите…" : "Нажмите и произнесите фразу")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }

    // MARK: - Что услышали

    private var heardCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text("Услышано")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)

            Text(recorder.transcript.isEmpty ? recognized : recorder.transcript)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)

            if let result {
                HStack(spacing: DS.Spacing.xs) {
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.Colors.border)
                        GeometryReader { geometry in
                            Capsule()
                                .fill(result.verdict.isAccepted ? DS.Colors.success : DS.Colors.warning)
                                .frame(width: geometry.size.width * result.score)
                        }
                    }
                    .frame(height: 8)

                    Text("\(result.percent)%")
                        .font(DS.Typography.counter)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .monospacedDigit()
                }

                if case .close(let missed) = result.verdict, !missed.isEmpty {
                    Text("Не расслышал: \(missed.joined(separator: ", "))")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Colors.surface)
        )
    }
}
