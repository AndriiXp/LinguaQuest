# Сборка #9 — failure

- Коммит: `2472b46d3a53d5ca0ea05f67663026a48250691e`
- Время: 2026-08-23 11:27 UTC
- Запуск: https://github.com/AndriiXp/LinguaQuest/actions/runs/32636339830

## Ошибки компиляции
```
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:162: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("Optional(["future", "good"])") is not equal to ("Optional(["good"])")
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:163: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("0") is not equal to ("1")
```

## Упавшие тесты
```
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:162: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("Optional(["future", "good"])") is not equal to ("Optional(["good"])")
/Users/runner/work/LinguaQuest/LinguaQuest/Packages/LinguaQuestKit/Tests/ContentModelsTests/ContentCatalogTests.swift:163: error: -[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped] : XCTAssertEqual failed: ("0") is not equal to ("1")
Test Case '-[ContentModelsTests.ContentCatalogTests testUnimplementedExerciseTypesAreSkipped]' failed (0.774 seconds).
```
