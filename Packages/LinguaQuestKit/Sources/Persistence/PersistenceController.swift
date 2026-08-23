import Foundation
import SwiftData

/// Сборка контейнера SwiftData. Все @Model-типы перечислены здесь —
/// забыть модель в схеме легко, и падение будет невнятным, поэтому список один.
public enum PersistenceController {

    public static let schema = Schema([
        UserProfile.self,
        UserSettings.self,
        UnlockedAvatar.self,
        SkillNode.self,
        LessonProgress.self,
        MistakeRecord.self,
        SRSCard.self,
        Achievement.self,
        DailyActivity.self
    ])

    /// - Parameter inMemory: true для превью и тестов — база живёт только в памяти.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Контейнер для SwiftUI-превью: в памяти и с уже созданным профилем.
    /// Используется только в `#Preview`, поэтому падение здесь — сигнал разработчику
    /// о сломанной схеме, а не аварийная ситуация у пользователя.
    @MainActor
    public static func previewContainer() -> ModelContainer {
        do {
            let container = try makeContainer(inMemory: true)
            let profile = UserProfile(displayName: "Превью", xpTotal: 320, level: 3, coins: 140, gems: 12,
                                      streakCount: 4, streakLastActive: Date(), streakFreezes: 1)
            profile.settings = UserSettings()
            container.mainContext.insert(profile)
            return container
        } catch {
            preconditionFailure("Схема SwiftData не собирается — проверьте модели: \(error)")
        }
    }
}
