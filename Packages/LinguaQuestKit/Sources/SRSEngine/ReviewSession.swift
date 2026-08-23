import Foundation
import Observation

/// Одна карточка в сессии повторения — независимая от способа хранения.
public struct ReviewItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let word: String
    public let translation: String
    public let example: String?
    public let state: SRSCardState

    public init(id: String, word: String, translation: String, example: String? = nil, state: SRSCardState) {
        self.id = id
        self.word = word
        self.translation = translation
        self.example = example
        self.state = state
    }
}

/// Результат по одной карточке: новое расписание и выставленная оценка.
public struct ReviewOutcome: Equatable, Sendable {
    public let itemId: String
    public let quality: ReviewQuality
    public let updatedState: SRSCardState

    public init(itemId: String, quality: ReviewQuality, updatedState: SRSCardState) {
        self.itemId = itemId
        self.quality = quality
        self.updatedState = updatedState
    }
}

/// Итог сессии повторения — показывается на финальном экране.
public struct ReviewSummary: Equatable, Sendable {
    public let total: Int
    public let remembered: Int
    public let forgotten: Int
    public let outcomes: [ReviewOutcome]
    public let duration: TimeInterval

    public init(total: Int, remembered: Int, forgotten: Int, outcomes: [ReviewOutcome], duration: TimeInterval) {
        self.total = total
        self.remembered = remembered
        self.forgotten = forgotten
        self.outcomes = outcomes
        self.duration = duration
    }

    public var accuracyPercent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(remembered) / Double(total) * 100).rounded())
    }
}

/// Как пользователь оценил своё воспоминание. Три кнопки вместо шести оценок SM-2:
/// больше вариантов люди всё равно не различают, а решение затягивается.
public enum RecallRating: String, CaseIterable, Sendable {
    case forgot
    case hard
    case easy

    var quality: ReviewQuality {
        switch self {
        case .forgot: return .blackout
        case .hard: return .hard
        case .easy: return .easy
        }
    }

    public var title: String {
        switch self {
        case .forgot: return "Не помню"
        case .hard: return "С трудом"
        case .easy: return "Легко"
        }
    }
}

/// Сессия повторения: показывает карточки по одной, принимает самооценку
/// и пересчитывает расписание через SM-2.
///
/// Забытые карточки возвращаются в конец очереди — слово, которое только что
/// не вспомнили, стоит увидеть ещё раз в этой же сессии.
@Observable
public final class ReviewSession {

    public enum Phase: Equatable {
        /// Слово показано, перевод скрыт — пользователь вспоминает.
        case recalling
        /// Перевод раскрыт, ждём самооценку.
        case revealed
        case finished(ReviewSummary)
    }

    public private(set) var phase: Phase = .recalling
    public private(set) var currentItem: ReviewItem?

    /// Сколько карточек закрыто из общего числа — для полосы прогресса.
    public private(set) var completedCount = 0
    public let totalCount: Int

    private var queue: [ReviewItem]
    private var outcomes: [String: ReviewOutcome] = [:]
    private var repeatedIds: Set<String> = []
    private let startedAt: Date
    private var itemShownAt: Date
    private let now: () -> Date
    private let calendar: Calendar

    public init(items: [ReviewItem], now: @escaping () -> Date = Date.init, calendar: Calendar = .current) {
        self.queue = items
        self.totalCount = items.count
        self.now = now
        self.calendar = calendar
        let start = now()
        self.startedAt = start
        self.itemShownAt = start
        self.currentItem = items.first

        if items.isEmpty {
            self.phase = .finished(ReviewSummary(total: 0, remembered: 0, forgotten: 0, outcomes: [], duration: 0))
        }
    }

    /// Показать перевод.
    public func reveal() {
        guard case .recalling = phase else { return }
        phase = .revealed
    }

    /// Принять самооценку и перейти к следующей карточке.
    public func rate(_ rating: RecallRating) {
        guard case .revealed = phase, let item = currentItem else { return }

        let reviewDate = now()
        let updated = SM2Scheduler.schedule(
            item.state,
            quality: rating.quality,
            reviewDate: reviewDate,
            calendar: calendar
        )
        // Итог по слову перезаписывается: если карточка вернулась после «не помню»,
        // в расписание пойдёт результат последнего показа.
        outcomes[item.id] = ReviewOutcome(itemId: item.id, quality: rating.quality, updatedState: updated)

        queue.removeFirst()

        // Забытое слово показываем ещё раз, но только один раз за сессию.
        if rating == .forgot && !repeatedIds.contains(item.id) {
            repeatedIds.insert(item.id)
            queue.append(ReviewItem(
                id: item.id,
                word: item.word,
                translation: item.translation,
                example: item.example,
                state: updated
            ))
        } else {
            completedCount += 1
        }

        if let next = queue.first {
            currentItem = next
            itemShownAt = now()
            phase = .recalling
        } else {
            finish()
        }
    }

    /// Досрочный выход: уже оценённые карточки сохраняют новое расписание.
    public func abandon() {
        finish()
    }

    public var progress: Double {
        guard totalCount > 0 else { return 1 }
        return min(1, Double(completedCount) / Double(totalCount))
    }

    /// Сколько времени пользователь смотрит на текущую карточку.
    public var timeOnCurrentItem: TimeInterval {
        now().timeIntervalSince(itemShownAt)
    }

    private func finish() {
        let results = Array(outcomes.values)
        let remembered = results.filter { !$0.quality.isFailure }.count
        phase = .finished(
            ReviewSummary(
                total: results.count,
                remembered: remembered,
                forgotten: results.count - remembered,
                outcomes: results.sorted { $0.itemId < $1.itemId },
                duration: now().timeIntervalSince(startedAt)
            )
        )
        currentItem = nil
    }
}
