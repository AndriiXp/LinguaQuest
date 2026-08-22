import Foundation

/// Категория навыка в дереве.
public enum SkillCategory: String, Codable, CaseIterable, Sendable {
    case grammar
    case vocab
    case listening
    case speaking
}

/// Уровень CEFR.
public enum CEFRLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"
    case c1 = "C1"
    case c2 = "C2"

    public static func < (lhs: CEFRLevel, rhs: CEFRLevel) -> Bool {
        guard let l = allCases.firstIndex(of: lhs), let r = allCases.firstIndex(of: rhs) else {
            return false
        }
        return l < r
    }
}

/// Один урок внутри навыка.
public struct LessonContent: Codable, Identifiable, Hashable, Sendable {
    public let lessonId: String
    public let title: String
    public let orderIndex: Int
    public let xpReward: Int
    public let exercises: [Exercise]

    public var id: String { lessonId }

    public init(lessonId: String, title: String, orderIndex: Int, xpReward: Int, exercises: [Exercise]) {
        self.lessonId = lessonId
        self.title = title
        self.orderIndex = orderIndex
        self.xpReward = xpReward
        self.exercises = exercises
    }
}

/// Навык — узел дерева, содержит несколько уроков.
public struct SkillContent: Codable, Identifiable, Hashable, Sendable {
    public let skillKey: String
    public let cefrLevel: CEFRLevel
    public let category: SkillCategory
    public let title: String
    public let subtitle: String?
    /// Имя SF Symbol для узла дерева.
    public let iconName: String
    public let prerequisiteKeys: [String]
    /// На какие открытые стандарты опирался генератор (для аудита копирайта).
    public let sourceStandard: String?
    public let lessons: [LessonContent]

    public var id: String { skillKey }

    public init(
        skillKey: String,
        cefrLevel: CEFRLevel,
        category: SkillCategory,
        title: String,
        subtitle: String? = nil,
        iconName: String,
        prerequisiteKeys: [String] = [],
        sourceStandard: String? = nil,
        lessons: [LessonContent]
    ) {
        self.skillKey = skillKey
        self.cefrLevel = cefrLevel
        self.category = category
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.prerequisiteKeys = prerequisiteKeys
        self.sourceStandard = sourceStandard
        self.lessons = lessons
    }

    /// Уроки в порядке прохождения.
    public var orderedLessons: [LessonContent] {
        lessons.sorted { $0.orderIndex < $1.orderIndex }
    }
}

/// Словарная единица — источник карточек SRS.
public struct VocabularyItem: Codable, Identifiable, Hashable, Sendable {
    public let itemId: String
    public let word: String
    public let translation: String
    public let partOfSpeech: String?
    public let cefrLevel: CEFRLevel
    public let exampleSentence: String?
    public let exampleTranslation: String?

    public var id: String { itemId }

    public init(
        itemId: String,
        word: String,
        translation: String,
        partOfSpeech: String? = nil,
        cefrLevel: CEFRLevel,
        exampleSentence: String? = nil,
        exampleTranslation: String? = nil
    ) {
        self.itemId = itemId
        self.word = word
        self.translation = translation
        self.partOfSpeech = partOfSpeech
        self.cefrLevel = cefrLevel
        self.exampleSentence = exampleSentence
        self.exampleTranslation = exampleTranslation
    }
}

/// Манифест бандла контента: какие файлы грузить и какая у контента версия.
public struct ContentManifest: Codable, Sendable {
    public let contentVersion: Int
    public let skillFiles: [String]
    public let vocabularyFile: String

    public init(contentVersion: Int, skillFiles: [String], vocabularyFile: String) {
        self.contentVersion = contentVersion
        self.skillFiles = skillFiles
        self.vocabularyFile = vocabularyFile
    }
}
