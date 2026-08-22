import Foundation
import Observation
import Core

public enum ContentError: LocalizedError, Equatable {
    case manifestNotFound
    case fileNotFound(String)
    case decodingFailed(file: String, reason: String)
    case emptyCatalog

    public var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "Не найден manifest.json в бандле контента"
        case .fileNotFound(let name):
            return "Не найден файл контента: \(name)"
        case .decodingFailed(let file, let reason):
            return "Ошибка разбора \(file): \(reason)"
        case .emptyCatalog:
            return "Каталог контента пуст"
        }
    }
}

/// Откуда берётся контент. В Фазе 1 — bundled JSON, в Фазе 2 рядом появится
/// FirestoreContentSource с тем же интерфейсом, и остальной код не изменится.
public protocol ContentSource {
    func loadCatalog() throws -> ContentCatalog.Payload
}

/// Каталог учебного контента: навыки, уроки, словарь.
/// Загружается один раз при старте и дальше живёт в памяти — объём Фазы 1 это позволяет.
@Observable
public final class ContentCatalog {

    public struct Payload: Sendable {
        public let manifest: ContentManifest
        public let skills: [SkillContent]
        public let vocabulary: [VocabularyItem]

        public init(manifest: ContentManifest, skills: [SkillContent], vocabulary: [VocabularyItem]) {
            self.manifest = manifest
            self.skills = skills
            self.vocabulary = vocabulary
        }
    }

    public private(set) var skills: [SkillContent] = []
    public private(set) var contentVersion: Int = 0
    /// Проблемы, найденные при валидации. Пустой массив = контент чистый.
    public private(set) var validationIssues: [String] = []

    private var vocabularyIndex: [String: VocabularyItem] = [:]
    private var lessonIndex: [String: (skill: SkillContent, lesson: LessonContent)] = [:]

    public init() {}

    /// Загружает и валидирует контент. Бросает только если контента нет вовсе.
    public func load(from source: ContentSource = BundledContentSource()) throws {
        let payload = try source.loadCatalog()

        var issues: [String] = []
        let cleanSkills = payload.skills.compactMap { skill -> SkillContent? in
            let lessons = skill.orderedLessons.compactMap { lesson -> LessonContent? in
                let exercises = lesson.exercises.filter { exercise in
                    if !exercise.type.isImplemented {
                        issues.append("\(lesson.lessonId)/\(exercise.id): тип \(exercise.type.rawValue) ещё не реализован — задание пропущено")
                        return false
                    }
                    if let error = exercise.validationError() {
                        issues.append("\(lesson.lessonId): \(error)")
                        return false
                    }
                    return true
                }
                guard !exercises.isEmpty else {
                    issues.append("\(lesson.lessonId): после валидации не осталось заданий — урок скрыт")
                    return nil
                }
                return LessonContent(
                    lessonId: lesson.lessonId,
                    title: lesson.title,
                    orderIndex: lesson.orderIndex,
                    xpReward: lesson.xpReward,
                    exercises: Self.orderedByDifficulty(exercises)
                )
            }
            guard !lessons.isEmpty else {
                issues.append("\(skill.skillKey): нет валидных уроков — навык скрыт")
                return nil
            }
            return SkillContent(
                skillKey: skill.skillKey,
                cefrLevel: skill.cefrLevel,
                category: skill.category,
                title: skill.title,
                subtitle: skill.subtitle,
                iconName: skill.iconName,
                prerequisiteKeys: skill.prerequisiteKeys,
                sourceStandard: skill.sourceStandard,
                lessons: lessons
            )
        }

        guard !cleanSkills.isEmpty else { throw ContentError.emptyCatalog }

        // Ссылка на несуществующий prerequisite сломала бы разблокировку дерева.
        let knownKeys = Set(cleanSkills.map(\.skillKey))
        for skill in cleanSkills {
            for key in skill.prerequisiteKeys where !knownKeys.contains(key) {
                issues.append("\(skill.skillKey): prerequisite '\(key)' отсутствует в каталоге")
            }
        }

        skills = cleanSkills
        contentVersion = payload.manifest.contentVersion
        vocabularyIndex = Dictionary(payload.vocabulary.map { ($0.itemId, $0) }, uniquingKeysWith: { first, _ in first })
        lessonIndex = [:]
        for skill in cleanSkills {
            for lesson in skill.lessons {
                lessonIndex[lesson.lessonId] = (skill, lesson)
            }
        }
        validationIssues = issues

        if issues.isEmpty {
            AppLog.content.info("Контент загружен: версия \(self.contentVersion), навыков \(cleanSkills.count)")
        } else {
            AppLog.content.warning("Контент загружен с замечаниями (\(issues.count)): \(issues.joined(separator: "; "))")
        }
    }

    /// Выстраивает задания урока по нарастающей сложности.
    /// Сортировка стабильная — задания одной сложности сохраняют порядок из файла,
    /// поэтому авторам контента не нужно вручную следить за очерёдностью.
    static func orderedByDifficulty(_ exercises: [Exercise]) -> [Exercise] {
        exercises.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.difficulty != rhs.element.difficulty {
                    return lhs.element.difficulty < rhs.element.difficulty
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    // MARK: - Доступ

    public func skill(for key: String) -> SkillContent? {
        skills.first { $0.skillKey == key }
    }

    public func lesson(id: String) -> LessonContent? {
        lessonIndex[id]?.lesson
    }

    public func skillOfLesson(id: String) -> SkillContent? {
        lessonIndex[id]?.skill
    }

    public func vocabulary(id: String) -> VocabularyItem? {
        vocabularyIndex[id]
    }

    public func vocabulary(ids: [String]) -> [VocabularyItem] {
        ids.compactMap { vocabularyIndex[$0] }
    }

    public var allVocabulary: [VocabularyItem] {
        Array(vocabularyIndex.values).sorted { $0.itemId < $1.itemId }
    }

    public func skills(for level: CEFRLevel) -> [SkillContent] {
        skills.filter { $0.cefrLevel == level }
    }
}
