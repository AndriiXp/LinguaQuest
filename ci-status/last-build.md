# Сборка #15 — failure

- Коммит: `48d7e5c536f2704a770ebaa07cedfa1ac76a3f08`
- Время: 2026-08-23 13:39 UTC
- Запуск: https://github.com/AndriiXp/LinguaQuest/actions/runs/32642707110

## Ошибки компиляции
```
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:165: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("Optional(["future", "good"])") is not equal to ("Optional(["good"])")
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:166: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("0") is not equal to ("1")
```

## Упавшие тесты
```
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:165: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("Optional(["future", "good"])") is not equal to ("Optional(["good"])")
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:166: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("0") is not equal to ("1")
Test Case '-[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped]' failed (0.581 seconds).
```
