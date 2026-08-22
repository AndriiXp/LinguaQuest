import SwiftUI
import Core

/// Нижний баннер с результатом ответа — визуальный якорь всего урока.
public struct FeedbackBanner: View {

    public enum Style {
        case correct
        case almost
        case incorrect

        var tint: Color {
            switch self {
            case .correct: return DS.Colors.success
            case .almost: return DS.Colors.warning
            case .incorrect: return DS.Colors.danger
            }
        }

        var background: Color {
            switch self {
            case .correct: return DS.Colors.successSoft
            case .almost: return DS.Colors.successSoft
            case .incorrect: return DS.Colors.dangerSoft
            }
        }

        var symbol: String {
            switch self {
            case .correct: return "checkmark.circle.fill"
            case .almost: return "checkmark.circle.badge.questionmark"
            case .incorrect: return "xmark.circle.fill"
            }
        }

        var title: String {
            switch self {
            case .correct: return "Верно!"
            case .almost: return "Почти верно"
            case .incorrect: return "Не совсем"
            }
        }
    }

    private let style: Style
    private let correctAnswer: String?
    private let explanation: String?
    private let buttonTitle: String
    private let action: () -> Void

    public init(
        style: Style,
        correctAnswer: String? = nil,
        explanation: String? = nil,
        buttonTitle: String = "Продолжить",
        action: @escaping () -> Void
    ) {
        self.style = style
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.buttonTitle = buttonTitle
        self.action = action
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: style.symbol)
                    .font(.title2)
                    .foregroundStyle(style.tint)
                Text(style.title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(style.tint)
            }

            if let correctAnswer, !correctAnswer.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Правильный ответ")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Text(correctAnswer)
                        .font(DS.Typography.bodyBold)
                        .foregroundStyle(DS.Colors.textPrimary)
                }
            }

            if let explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ActionButton(buttonTitle, role: style == .incorrect ? .danger : .success, action: action)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: DS.Radius.xl,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: DS.Radius.xl,
                style: .continuous
            )
            .fill(style.background)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }
}

#Preview {
    VStack {
        Spacer()
        FeedbackBanner(
            style: .incorrect,
            correctAnswer: "drinks",
            explanation: "После he / she / it в Present Simple глагол получает окончание -s."
        ) {}
    }
    .background(DS.Colors.background)
}
