// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LinguaQuestKit",
    defaultLocalization: "ru",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "ContentModels", targets: ["ContentModels"]),
        .library(name: "SRSEngine", targets: ["SRSEngine"]),
        .library(name: "LessonEngine", targets: ["LessonEngine"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "UIComponents", targets: ["UIComponents"])
    ],
    targets: [
        // Дизайн-токены, тема, навигация, утилиты. Без бизнес-логики.
        .target(
            name: "Core",
            path: "Sources/Core"
        ),

        // Codable-модели учебного контента + загрузчик bundled JSON.
        .target(
            name: "ContentModels",
            dependencies: ["Core"],
            path: "Sources/ContentModels",
            resources: [.copy("Resources/Content")]
        ),

        // Алгоритм интервального повтора SM-2. Чистая логика, без UI.
        .target(
            name: "SRSEngine",
            dependencies: ["Core"],
            path: "Sources/SRSEngine"
        ),

        // Движок урока: стейт-машина, валидация ответов, жизни, подсчёт XP.
        .target(
            name: "LessonEngine",
            dependencies: ["Core", "ContentModels"],
            path: "Sources/LessonEngine"
        ),

        // SwiftData-модели и репозитории.
        .target(
            name: "Persistence",
            dependencies: ["Core", "ContentModels", "SRSEngine"],
            path: "Sources/Persistence"
        ),

        // Переиспользуемые SwiftUI-компоненты.
        .target(
            name: "UIComponents",
            dependencies: ["Core"],
            path: "Sources/UIComponents"
        ),

        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "Tests/CoreTests"
        ),
        .testTarget(
            name: "LessonEngineTests",
            dependencies: ["LessonEngine", "ContentModels", "Core"],
            path: "Tests/LessonEngineTests"
        ),
        .testTarget(
            name: "SRSEngineTests",
            dependencies: ["SRSEngine"],
            path: "Tests/SRSEngineTests"
        ),
        .testTarget(
            name: "ContentModelsTests",
            dependencies: ["ContentModels"],
            path: "Tests/ContentModelsTests"
        )
    ]
)
