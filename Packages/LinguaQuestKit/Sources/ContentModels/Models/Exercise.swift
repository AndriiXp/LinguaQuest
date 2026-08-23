import Foundation

/// Типы заданий движка урока. Фаза 1 реализует первые три,
/// остальные описаны в модели заранее, чтобы контент не пришлось мигрировать.
public enum ExerciseType: String, Codable, CaseIterable, Sendable {
    case multipleChoice = "multiple_choice"
    case typeAnswer = "type_answer"
    case matchPairs = "match_pairs"
    case wordOrder = "word_order"
    case fillBlank = "fill_blank"
    case listening
    case speaking

    /// Реализован ли тип в текущей сборке. Нереализованные задания
    /// загрузчик отфильтровывает, чтобы урок не упирался в пустой экран.
    public var isImplemented: Bool {
        switch self {
        case .multipleChoice, .typeAnswer, .matchPairs, .wordOrder, .fillBlank:
            return true
        case .listening, .speaking:
            // Ждут Спринта 4: TTS и распознавание речи.
            return false
        }
    }
}

/// Пара «слово ↔ перевод» для задания на сопоставление.
public struct MatchPair: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let left: String
    public let right: String

    public init(id: String, left: String, right: String) {
        self.id = id
        self.left = left
        self.right = right
    }
}

/// Одно задание урока.
///
/// Модель намеренно «плоская» с опциональными полями — так же, как в JSON-схеме из ТЗ.
/// Валидность конкретного типа проверяет `validate()`, а не система типов:
/// контент приходит из внешнего файла и может быть повреждён.
public struct Exercise: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let type: ExerciseType
    /// Текст задания. Для fill_blank содержит маркер пропуска `___`.
    public let prompt: String
    /// Перевод задания на русский — подсказка для A1.
    public let promptTranslation: String?
    /// Эталонный ответ.
    public let correctAnswer: String?
    /// Дополнительные принимаемые варианты (синонимы, сокращения).
    public let acceptedAnswers: [String]?
    /// Варианты для multiple_choice (включая правильный).
    public let options: [String]?
    /// Пары для match_pairs.
    public let pairs: [MatchPair]?
    /// Слова для word_order (в перемешанном виде их подаёт движок).
    public let tokens: [String]?
    /// Текст для озвучки TTS (Фаза 1 обходится без аудиофайлов).
    public let audioText: String?
    public let hint: String?
    /// Объяснение правила, показывается после ошибки.
    public let explanation: String?
    /// 1...3 — сложность внутри урока.
    public let difficulty: Int
    /// Какие словарные единицы затрагивает задание — из них рождаются SRS-карточки.
    public let vocabularyIds: [String]?
    /// Категория ошибки для аналитики и адаптивности (Фаза 2).
    public let errorCategory: String?

    public init(
        id: String,
        type: ExerciseType,
        prompt: String,
        promptTranslation: String? = nil,
        correctAnswer: String? = nil,
        acceptedAnswers: [String]? = nil,
        options: [String]? = nil,
        pairs: [MatchPair]? = nil,
        tokens: [String]? = nil,
        audioText: String? = nil,
        hint: String? = nil,
        explanation: String? = nil,
        difficulty: Int = 1,
        vocabularyIds: [String]? = nil,
        errorCategory: String? = nil
    ) {
        self.id = id
        self.type = type
        self.prompt = prompt
        self.promptTranslation = promptTranslation
        self.correctAnswer = correctAnswer
        self.acceptedAnswers = acceptedAnswers
        self.options = options
        self.pairs = pairs
        self.tokens = tokens
        self.audioText = audioText
        self.hint = hint
        self.explanation = explanation
        self.difficulty = difficulty
        self.vocabularyIds = vocabularyIds
        self.errorCategory = errorCategory
    }

    /// Все ответы, которые считаются верными.
    public var allCorrectAnswers: [String] {
        var result: [String] = []
        if let correctAnswer { result.append(correctAnswer) }
        if let acceptedAnswers { result.append(contentsOf: acceptedAnswers) }
        return result
    }

    /// Проверяет, что задание пригодно к показу. Возвращает описание проблемы или nil.
    public func validationError() -> String? {
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "exercise \(id): пустой prompt"
        }
        switch type {
        case .multipleChoice, .listening:
            guard let options, options.count >= 2 else {
                return "exercise \(id): нужно минимум 2 варианта ответа"
            }
            guard let correctAnswer else {
                return "exercise \(id): не задан correctAnswer"
            }
            guard options.contains(correctAnswer) else {
                return "exercise \(id): correctAnswer отсутствует среди options"
            }
            guard Set(options).count == options.count else {
                return "exercise \(id): варианты ответа дублируются"
            }
        case .typeAnswer, .speaking:
            guard correctAnswer?.isEmpty == false else {
                return "exercise \(id): не задан correctAnswer"
            }
        case .fillBlank:
            guard correctAnswer?.isEmpty == false else {
                return "exercise \(id): не задан correctAnswer"
            }
            guard prompt.contains("___") else {
                return "exercise \(id): в prompt нет маркера пропуска ___"
            }
        case .matchPairs:
            guard let pairs, pairs.count >= 2 else {
                return "exercise \(id): нужно минимум 2 пары"
            }
            guard Set(pairs.map(\.id)).count == pairs.count else {
                return "exercise \(id): id пар дублируются"
            }
            guard Set(pairs.map(\.right)).count == pairs.count else {
                return "exercise \(id): правые части пар дублируются — сопоставление станет неоднозначным"
            }
        case .wordOrder:
            guard let tokens, tokens.count >= 2 else {
                return "exercise \(id): нужно минимум 2 слова"
            }
            guard correctAnswer?.isEmpty == false else {
                return "exercise \(id): не задан correctAnswer"
            }
        }
        return nil
    }
}
