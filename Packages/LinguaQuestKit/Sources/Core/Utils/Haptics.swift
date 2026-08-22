import Foundation
import UIKit

/// Тактильная отдача. Вынесена в отдельный тип, чтобы её можно было
/// глобально выключить настройкой и не дублировать генераторы по экранам.
@MainActor
public enum Haptics {
    /// Управляется настройкой пользователя (звук/вибрация).
    public static var isEnabled = true

    public static func success() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    public static func error() {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    public static func light() {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    public static func selection() {
        guard isEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
