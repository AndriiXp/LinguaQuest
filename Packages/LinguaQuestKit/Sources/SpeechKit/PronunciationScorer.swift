import Foundation

/// Насколько произнесённое совпало с эталоном.
public enum PronunciationVerdict: Equatable, Sendable {
    /// Распознано верно.
    case correct
    /// Слова угаданы, но не все — засчитываем, показываем эталон.
    case close(missed: [String])
    /// Не похоже на эталон.
    case wrong(heard: String)
    /// Ничего не расслышали: тишина, шум, слишком тихо.
    case notHeard

    public var isAccepted: Bool {
        switch self {
        case .correct, .close: return true
        case .wrong, .notHeard: return false
        }
    }
}

/// Результат проверки произношения с числовой оценкой — по ней рисуется шкала.
public struct PronunciationResult: Equatable, Sendable {
    public let verdict: PronunciationVerdict
    /// Доля совпавших слов, 0...1.
    public let score: Double
    public let recognizedText: String

    public init(verdict: PronunciationVerdict, score: Double, recognizedText: String) {
        self.verdict = verdict
        self.score = score
        self.recognizedText = recognizedText
    }

    public var percent: Int { Int((score * 100).rounded()) }
}

/// Сравнивает распознанный текст с эталонной фразой.
///
/// Задача не в фонетике: Speech framework уже вернул текст, и мы проверяем,
/// те ли слова человек сказал. Оценка мягкая намеренно — распознавание ошибается
/// на акценте, и штрафовать за это несправедливо.
public enum PronunciationScorer {

    /// Доля слов, начиная с которой ответ считается принятым.
    public static let acceptThreshold = 0.6
    /// Доля, начиная с которой ответ считается безупречным.
    public static let perfectThreshold = 0.95

    /// Приводит фразу к списку значимых слов.
    public static func words(in phrase: String) -> [String] {
        phrase
            .lowercased()
            .map { $0.isLetter || $0.isNumber || $0 == "'" ? $0 : " " }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .map(String.init)
    }

    /// Сравнивает распознанное с эталоном.
    public static func score(recognized: String, expected: String) -> PronunciationResult {
        let expectedWords = words(in: expected)
        let recognizedWords = words(in: recognized)

        guard !expectedWords.isEmpty else {
            return PronunciationResult(verdict: .notHeard, score: 0, recognizedText: recognized)
        }
        guard !recognizedWords.isEmpty else {
            return PronunciationResult(verdict: .notHeard, score: 0, recognizedText: recognized)
        }

        // Каждое слово эталона ищем среди распознанных, вычёркивая найденное:
        // повтор слова в эталоне должен требовать двух совпадений, а не одного.
        var available = recognizedWords
        var matched: [String] = []
        var missed: [String] = []

        for word in expectedWords {
            if let index = available.firstIndex(where: { isSameWord($0, word) }) {
                available.remove(at: index)
                matched.append(word)
            } else {
                missed.append(word)
            }
        }

        let score = Double(matched.count) / Double(expectedWords.count)

        let verdict: PronunciationVerdict
        if score >= perfectThreshold {
            verdict = .correct
        } else if score >= acceptThreshold {
            verdict = .close(missed: missed)
        } else {
            verdict = .wrong(heard: recognized)
        }

        return PronunciationResult(verdict: verdict, score: score, recognizedText: recognized)
    }

    /// Считает слова одинаковыми, прощая мелкие расхождения распознавания.
    static func isSameWord(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        // Распознаватель часто путает окончания: work / works, drink / drinks.
        // Для оценки произношения это не та ошибка, за которую стоит наказывать.
        if lhs.count >= 4 && rhs.count >= 4 {
            if lhs.hasPrefix(rhs) || rhs.hasPrefix(lhs) {
                return abs(lhs.count - rhs.count) <= 2
            }
            if levenshtein(lhs, rhs) <= 1 { return true }
        }
        return false
    }

    static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            previous = current
        }
        return previous[b.count]
    }
}
