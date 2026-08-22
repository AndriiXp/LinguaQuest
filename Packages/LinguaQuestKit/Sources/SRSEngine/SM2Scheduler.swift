import Foundation

/// Оценка ответа на карточку в терминах SM-2.
/// Пользователь не выставляет её вручную — движок выводит её из того,
/// как быстро и с какой попытки был дан ответ.
public enum ReviewQuality: Int, CaseIterable, Sendable {
    case blackout = 0        // не вспомнил вообще
    case wrongRemembered = 1 // ответил неверно, но узнал ответ
    case wrongEasy = 2       // неверно, ответ показался очевидным
    case hard = 3            // верно, но с трудом
    case good = 4            // верно, с небольшой паузой
    case easy = 5            // верно и мгновенно

    public var isFailure: Bool { rawValue < 3 }

    /// Выводит оценку из факта правильности, времени ответа и числа подсказок.
    public static func infer(isCorrect: Bool, responseTime: TimeInterval, usedHint: Bool) -> ReviewQuality {
        guard isCorrect else { return usedHint ? .wrongRemembered : .blackout }
        if usedHint { return .hard }
        switch responseTime {
        case ..<3: return .easy
        case ..<8: return .good
        default: return .hard
        }
    }
}

/// Состояние карточки интервального повтора. Чистое значение — SwiftData-модель
/// хранит те же поля и конвертируется в этот тип на время расчёта.
public struct SRSCardState: Equatable, Sendable {
    public var easeFactor: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var lapses: Int
    public var nextReviewDate: Date
    public var lastReviewedAt: Date?

    public init(
        easeFactor: Double = 2.5,
        intervalDays: Int = 0,
        repetitions: Int = 0,
        lapses: Int = 0,
        nextReviewDate: Date = Date(),
        lastReviewedAt: Date? = nil
    ) {
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.lapses = lapses
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
    }
}

/// Алгоритм SM-2 в варианте из ТЗ (раздел 5.1).
public enum SM2Scheduler {

    /// Нижняя граница easeFactor из оригинального SM-2.
    public static let minimumEaseFactor = 1.3
    /// Стартовый easeFactor новой карточки.
    public static let defaultEaseFactor = 2.5
    /// Потолок интервала — чтобы карточка не улетала на десятилетия.
    public static let maximumIntervalDays = 365

    /// Пересчитывает состояние карточки после ответа.
    /// - Parameters:
    ///   - state: текущее состояние карточки
    ///   - quality: оценка ответа
    ///   - reviewDate: момент ответа (обычно `Date()`; параметр нужен тестам)
    ///   - calendar: календарь для вычисления следующей даты
    public static func schedule(
        _ state: SRSCardState,
        quality: ReviewQuality,
        reviewDate: Date = Date(),
        calendar: Calendar = .current
    ) -> SRSCardState {
        var updated = state
        let q = quality.rawValue

        if quality.isFailure {
            updated.repetitions = 0
            updated.intervalDays = 1
            updated.lapses += 1
        } else {
            switch state.repetitions {
            case 0:
                updated.intervalDays = 1
            case 1:
                updated.intervalDays = 6
            default:
                let next = Double(state.intervalDays) * state.easeFactor
                updated.intervalDays = min(maximumIntervalDays, Int(next.rounded()))
            }
            updated.repetitions = state.repetitions + 1
        }

        // easeFactor корректируется всегда, в том числе после ошибки.
        let delta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
        updated.easeFactor = max(minimumEaseFactor, state.easeFactor + delta)

        updated.intervalDays = max(1, updated.intervalDays)
        updated.lastReviewedAt = reviewDate
        updated.nextReviewDate = calendar.date(
            byAdding: .day,
            value: updated.intervalDays,
            to: calendar.startOfDay(for: reviewDate)
        ) ?? reviewDate.addingTimeInterval(Double(updated.intervalDays) * 86_400)

        return updated
    }

    /// Состояние только что созданной карточки: к повтору сегодня же.
    public static func newCard(createdAt: Date = Date()) -> SRSCardState {
        SRSCardState(
            easeFactor: defaultEaseFactor,
            intervalDays: 0,
            repetitions: 0,
            lapses: 0,
            nextReviewDate: createdAt,
            lastReviewedAt: nil
        )
    }

    /// Пора ли повторять карточку на дату `date`.
    public static func isDue(_ state: SRSCardState, on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: state.nextReviewDate) <= calendar.startOfDay(for: date)
    }
}
