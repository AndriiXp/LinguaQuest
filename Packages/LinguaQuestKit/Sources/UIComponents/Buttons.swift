import SwiftUI
import Core

/// Роль кнопки определяет цвет — вызывающий код не подбирает оттенки вручную.
public enum ActionButtonRole {
    case primary
    case success
    case danger
    case secondary

    var background: Color {
        switch self {
        case .primary: return DS.Colors.primary
        case .success: return DS.Colors.success
        case .danger: return DS.Colors.danger
        case .secondary: return DS.Colors.surface
        }
    }

    var foreground: Color {
        switch self {
        case .secondary: return DS.Colors.textPrimary
        default: return .white
        }
    }

    var border: Color? {
        self == .secondary ? DS.Colors.border : nil
    }
}

/// Основная кнопка приложения: крупная, с тактильной отдачей и состоянием disabled.
public struct ActionButton: View {
    private let title: String
    private let role: ActionButtonRole
    private let icon: String?
    private let isEnabled: Bool
    private let action: () -> Void

    @State private var isPressed = false

    public init(
        _ title: String,
        role: ActionButtonRole = .primary,
        icon: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(DS.Typography.bodyBold)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .frame(maxWidth: .infinity)
            // minHeight, а не фиксированная высота: на крупных размерах
            // Dynamic Type кнопка обязана расти, а не обрезать текст.
            .frame(minHeight: DS.Size.buttonHeight)
            .foregroundStyle(role.foreground)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(role.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .strokeBorder(role.border ?? .clear, lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(DS.Motion.quick) { isPressed = true } }
                .onEnded { _ in withAnimation(DS.Motion.quick) { isPressed = false } }
        )
        .accessibilityLabel(title)
    }
}

/// Состояние варианта ответа для карточек выбора.
public enum ChoiceState {
    case idle
    case selected
    case correct
    case incorrect

    var border: Color {
        switch self {
        case .idle: return DS.Colors.border
        case .selected: return DS.Colors.primary
        case .correct: return DS.Colors.success
        case .incorrect: return DS.Colors.danger
        }
    }

    var background: Color {
        switch self {
        case .idle: return DS.Colors.surface
        case .selected: return DS.Colors.primarySoft
        case .correct: return DS.Colors.successSoft
        case .incorrect: return DS.Colors.dangerSoft
        }
    }
}

/// Карточка варианта ответа.
public struct ChoiceCard: View {
    private let text: String
    private let state: ChoiceState
    private let action: () -> Void

    public init(text: String, state: ChoiceState, action: @escaping () -> Void) {
        self.text = text
        self.state = state
        self.action = action
    }

    public var body: some View {
        Button(action: {
            Haptics.selection()
            action()
        }) {
            Text(text)
                .font(DS.Typography.body)
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(state.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(state.border, lineWidth: state == .idle ? 1 : 2)
                )
        }
        .buttonStyle(.plain)
        .animation(DS.Motion.quick, value: state)
    }
}

#Preview {
    VStack(spacing: DS.Spacing.md) {
        ActionButton("Проверить") {}
        ActionButton("Продолжить", role: .success, icon: "arrow.right") {}
        ActionButton("Пропустить", role: .secondary) {}
        ActionButton("Недоступно", isEnabled: false) {}
        ChoiceCard(text: "drinks", state: .idle) {}
        ChoiceCard(text: "drink", state: .incorrect) {}
    }
    .padding()
    .background(DS.Colors.background)
}
