import Foundation
import OSLog

/// Логгеры по подсистемам — чтобы фильтровать вывод в Console.app по категориям.
public enum AppLog {
    private static let subsystem = "com.linguaquest.app"

    public static let content = Logger(subsystem: subsystem, category: "content")
    public static let lesson = Logger(subsystem: subsystem, category: "lesson")
    public static let srs = Logger(subsystem: subsystem, category: "srs")
    public static let persistence = Logger(subsystem: subsystem, category: "persistence")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
