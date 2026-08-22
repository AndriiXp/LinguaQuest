import XCTest
@testable import ContentModels

final class ContentCatalogTests: XCTestCase {

    // MARK: - Реальный bundled-контент

    func testBundledContentLoadsWithoutIssues() throws {
        let catalog = ContentCatalog()
        try catalog.load()

        XCTAssertFalse(catalog.skills.isEmpty, "Каталог не должен быть пустым")
        XCTAssertEqual(catalog.validationIssues, [], "Контент в бандле обязан быть чистым")
        XCTAssertGreaterThan(catalog.contentVersion, 0)
    }

    func testEveryLessonHasExercisesAndUniqueIds() throws {
        let catalog = ContentCatalog()
        try catalog.load()

        var lessonIds = Set<String>()
        for skill in catalog.skills {
            XCTAssertFalse(skill.lessons.isEmpty, "\(skill.skillKey): нет уроков")
            for lesson in skill.lessons {
                XCTAssertTrue(lessonIds.insert(lesson.lessonId).inserted, "Дубликат урока \(lesson.lessonId)")
                XCTAssertFalse(lesson.exercises.isEmpty, "\(lesson.lessonId): нет заданий")
                XCTAssertGreaterThan(lesson.xpReward, 0)

                var exerciseIds = Set<String>()
                for exercise in lesson.exercises {
                    XCTAssertTrue(
                        exerciseIds.insert(exercise.id).inserted,
                        "\(lesson.lessonId): дубликат задания \(exercise.id)"
                    )
                    XCTAssertNil(exercise.validationError())
                    XCTAssertTrue(exercise.type.isImplemented)
                }
            }
        }
    }

    func testVocabularyReferencesResolve() throws {
        let catalog = ContentCatalog()
        try catalog.load()

        for skill in catalog.skills {
            for lesson in skill.lessons {
                for exercise in lesson.exercises {
                    for id in exercise.vocabularyIds ?? [] {
                        XCTAssertNotNil(
                            catalog.vocabulary(id: id),
                            "\(exercise.id): слово \(id) отсутствует в словаре"
                        )
                    }
                }
            }
        }
    }

    func testSkillTreeHasRootAndResolvablePrerequisites() throws {
        let catalog = ContentCatalog()
        try catalog.load()

        let keys = Set(catalog.skills.map(\.skillKey))
        XCTAssertTrue(
            catalog.skills.contains { $0.prerequisiteKeys.isEmpty },
            "Нужен хотя бы один навык без предпосылок, иначе дерево не открыть"
        )
        for skill in catalog.skills {
            for prerequisite in skill.prerequisiteKeys {
                XCTAssertTrue(keys.contains(prerequisite), "\(skill.skillKey): нет навыка \(prerequisite)")
                XCTAssertNotEqual(prerequisite, skill.skillKey)
            }
        }
    }

    func testLessonAndSkillLookup() throws {
        let catalog = ContentCatalog()
        try catalog.load()

        let firstSkill = try XCTUnwrap(catalog.skills.first)
        let firstLesson = try XCTUnwrap(firstSkill.orderedLessons.first)

        XCTAssertEqual(catalog.skill(for: firstSkill.skillKey)?.skillKey, firstSkill.skillKey)
        XCTAssertEqual(catalog.lesson(id: firstLesson.lessonId)?.lessonId, firstLesson.lessonId)
        XCTAssertEqual(catalog.skillOfLesson(id: firstLesson.lessonId)?.skillKey, firstSkill.skillKey)
        XCTAssertNil(catalog.lesson(id: "не существует"))
    }

    // MARK: - Валидация повреждённого контента

    func testInvalidExercisesAreFilteredOut() throws {
        let broken = Exercise(
            id: "broken",
            type: .multipleChoice,
            prompt: "Вопрос",
            correctAnswer: "нет в вариантах",
            options: ["a", "b"]
        )
        let good = Exercise(
            id: "good",
            type: .multipleChoice,
            prompt: "Вопрос",
            correctAnswer: "a",
            options: ["a", "b"]
        )
        let skill = SkillContent(
            skillKey: "s1",
            cefrLevel: .a1,
            category: .grammar,
            title: "Тест",
            iconName: "star",
            lessons: [LessonContent(lessonId: "l1", title: "Урок", orderIndex: 1, xpReward: 10, exercises: [broken, good])]
        )

        let catalog = ContentCatalog()
        try catalog.load(from: InMemoryContentSource(skills: [skill]))

        XCTAssertEqual(catalog.lesson(id: "l1")?.exercises.count, 1)
        XCTAssertEqual(catalog.lesson(id: "l1")?.exercises.first?.id, "good")
        XCTAssertEqual(catalog.validationIssues.count, 1)
    }

    func testLessonWithoutValidExercisesIsHidden() throws {
        let broken = Exercise(id: "b", type: .typeAnswer, prompt: "Вопрос", correctAnswer: nil)
        let skill = SkillContent(
            skillKey: "s1",
            cefrLevel: .a1,
            category: .grammar,
            title: "Тест",
            iconName: "star",
            lessons: [LessonContent(lessonId: "l1", title: "Урок", orderIndex: 1, xpReward: 10, exercises: [broken])]
        )

        let catalog = ContentCatalog()
        XCTAssertThrowsError(try catalog.load(from: InMemoryContentSource(skills: [skill]))) { error in
            XCTAssertEqual(error as? ContentError, .emptyCatalog)
        }
    }

    func testUnimplementedExerciseTypesAreSkipped() throws {
        let future = Exercise(
            id: "future",
            type: .wordOrder,
            prompt: "Соберите предложение",
            correctAnswer: "I read books",
            tokens: ["I", "read", "books"]
        )
        let good = Exercise(id: "good", type: .typeAnswer, prompt: "Переведите", correctAnswer: "water")
        let skill = SkillContent(
            skillKey: "s1",
            cefrLevel: .a1,
            category: .vocab,
            title: "Тест",
            iconName: "star",
            lessons: [LessonContent(lessonId: "l1", title: "Урок", orderIndex: 1, xpReward: 10, exercises: [future, good])]
        )

        let catalog = ContentCatalog()
        try catalog.load(from: InMemoryContentSource(skills: [skill]))

        XCTAssertEqual(catalog.lesson(id: "l1")?.exercises.map(\.id), ["good"])
        XCTAssertEqual(catalog.validationIssues.count, 1)
    }

    // MARK: - Правила валидации заданий

    func testExerciseValidationRules() {
        let missingOption = Exercise(
            id: "e", type: .multipleChoice, prompt: "p", correctAnswer: "x", options: ["a", "b"]
        )
        XCTAssertNotNil(missingOption.validationError())

        let duplicateOptions = Exercise(
            id: "e", type: .multipleChoice, prompt: "p", correctAnswer: "a", options: ["a", "a"]
        )
        XCTAssertNotNil(duplicateOptions.validationError())

        let ambiguousPairs = Exercise(
            id: "e",
            type: .matchPairs,
            prompt: "p",
            pairs: [
                MatchPair(id: "1", left: "a", right: "одно"),
                MatchPair(id: "2", left: "b", right: "одно")
            ]
        )
        XCTAssertNotNil(ambiguousPairs.validationError(), "Одинаковые правые части делают ответ неоднозначным")

        let fillBlankWithoutMarker = Exercise(
            id: "e", type: .fillBlank, prompt: "нет пропуска", correctAnswer: "a"
        )
        XCTAssertNotNil(fillBlankWithoutMarker.validationError())

        let valid = Exercise(
            id: "e", type: .multipleChoice, prompt: "p", correctAnswer: "a", options: ["a", "b"]
        )
        XCTAssertNil(valid.validationError())
    }

    func testExercisesAreOrderedByDifficulty() throws {
        let catalog = ContentCatalog()
        try catalog.load()

        for skill in catalog.skills {
            for lesson in skill.lessons {
                let difficulties = lesson.exercises.map(\.difficulty)
                XCTAssertEqual(
                    difficulties, difficulties.sorted(),
                    "\(lesson.lessonId): сложность заданий должна нарастать"
                )
            }
        }
    }

    func testDifficultyOrderingIsStable() {
        let easyFirst = Exercise(id: "a", type: .typeAnswer, prompt: "p", correctAnswer: "x", difficulty: 1)
        let hard = Exercise(id: "b", type: .typeAnswer, prompt: "p", correctAnswer: "x", difficulty: 3)
        let easySecond = Exercise(id: "c", type: .typeAnswer, prompt: "p", correctAnswer: "x", difficulty: 1)

        let ordered = ContentCatalog.orderedByDifficulty([easyFirst, hard, easySecond])

        // Равные сложности сохраняют исходный порядок.
        XCTAssertEqual(ordered.map(\.id), ["a", "c", "b"])
    }

    func testCEFRLevelsAreComparable() {
        XCTAssertLessThan(CEFRLevel.a1, CEFRLevel.a2)
        XCTAssertLessThan(CEFRLevel.b1, CEFRLevel.c1)
        XCTAssertFalse(CEFRLevel.b2 < CEFRLevel.a1)
    }
}
