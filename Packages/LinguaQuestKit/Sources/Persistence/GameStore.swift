import Foundation
import Observation
import SwiftData
import Core
import ContentModels
import SRSEngine
import LessonEngine

/// Центральный игровой сервис: единственное место, где меняется состояние игрока.
///
/// Экраны читают его свойства и вызывают его методы — прямых обращений к ModelContext
/// из вью нет, поэтому правила прогрессии не расползаются по UI.
@MainActor
@Observable
public final class GameStore {

    public private(set) var profile: UserProfile
    public let catalog: ContentCatalog

    /// Событие streak после последнего урока — экран Complete показывает по нему анимацию.
    public private(set) var lastStreakEvent: StreakEvent = .unchanged
    /// Аватары, открывшиеся после последнего повышения уровня.
    public private(set) var newlyUnlockedAvatars: [AvatarItem] = []
    /// Уровень вырос в результате последнего урока.
    public private(set) var didLevelUp = false
    /// Сколько карточек назначено на сегодня. Кэш, а не запрос из тела вью:
    /// иначе SwiftData-фетч выполнялся бы на каждую перерисовку экрана.
    public private(set) var dueCardsCount = 0
    /// Достижения, открывшиеся последним уроком — экран итогов показывает их.
    public private(set) var newlyUnlockedAchievements: [AchievementDefinition] = []

    private let context: ModelContext
    private let now: () -> Date

    public init(
        context: ModelContext,
        catalog: ContentCatalog,
        now: @escaping () -> Date = Date.init
    ) throws {
        self.context = context
        self.catalog = catalog
        self.now = now
        self.profile = try Self.loadOrCreateProfile(in: context, now: now())
        try syncSkillNodes()
        refreshDailyCounters()
        refreshStreak()
        refreshDueCardsCount()
        syncAchievements()
        save()
    }

    /// Пересчитывает кэш карточек к повторению. Вызывается после урока
    /// и при появлении экранов, которые этот счётчик показывают.
    public func refreshDueCardsCount() {
        dueCardsCount = dueCards().count
    }

    // MARK: - Профиль

    private static func loadOrCreateProfile(in context: ModelContext, now: Date) throws -> UserProfile {
        let existing = try context.fetch(FetchDescriptor<UserProfile>())
        if let profile = existing.first {
            if profile.settings == nil {
                profile.settings = UserSettings()
            }
            return profile
        }

        let profile = UserProfile(
            displayName: "Гость",
            dailyGoalXP: GameRules.DailyGoal.regular.xp,
            todayXPDate: now,
            createdAt: now
        )
        profile.settings = UserSettings()
        profile.unlockedAvatars = AvatarCatalog.defaults.map { UnlockedAvatar(avatarId: $0.id, unlockedAt: now) }
        context.insert(profile)
        try context.save()
        AppLog.persistence.info("Создан гостевой профиль")
        return profile
    }

    /// Обнуляет дневной счётчик XP при смене календарного дня.
    public func refreshDailyCounters() {
        let calendar = Calendar.current
        if !calendar.isDate(profile.todayXPDate, inSameDayAs: now()) {
            profile.todayXP = 0
            profile.todayXPDate = now()
            save()
        }
    }

    /// Пересчитывает streak при запуске: списывает заморозки или обнуляет серию.
    public func refreshStreak() {
        let state = StreakState(
            count: profile.streakCount,
            freezes: profile.streakFreezes,
            lastActiveDay: profile.streakLastActive
        )
        let (updated, event) = StreakCalculator.refresh(state, now: now())
        applyStreak(updated)
        lastStreakEvent = event
        if event != .unchanged { save() }
    }

    private func applyStreak(_ state: StreakState) {
        profile.streakCount = state.count
        profile.streakFreezes = state.freezes
        profile.streakLastActive = state.lastActiveDay
    }

    // MARK: - Сердца

    public var hearts: HeartsState {
        HeartsState(count: profile.heartsCount, lastSpentAt: profile.heartsLastSpentAt)
    }

    public func persist(hearts: HeartsState) {
        profile.heartsCount = hearts.current(at: now())
        profile.heartsLastSpentAt = hearts.current(at: now()) >= GameRules.maxHearts ? nil : hearts.lastSpentAt
        save()
    }

    /// Бесплатное восстановление — новый день, подписка, отладка.
    public func refillHearts() {
        profile.heartsCount = GameRules.maxHearts
        profile.heartsLastSpentAt = nil
        save()
    }

    /// Восстановление за кристаллы. Возвращает false, если валюты не хватило.
    @discardableResult
    public func purchaseHeartRefill() -> Bool {
        guard profile.gems >= GameRules.refillHeartsGemPrice else { return false }
        profile.gems -= GameRules.refillHeartsGemPrice
        refillHearts()
        return true
    }

    // MARK: - Дерево навыков

    /// Приводит записи прогресса в соответствие с каталогом контента:
    /// добавляет новые навыки/уроки и пересчитывает разблокировку.
    public func syncSkillNodes() throws {
        let existingNodes = try context.fetch(FetchDescriptor<SkillNode>())
        var nodesByKey = Dictionary(existingNodes.map { ($0.skillKey, $0) }, uniquingKeysWith: { first, _ in first })

        for skill in catalog.skills {
            let node: SkillNode
            if let found = nodesByKey[skill.skillKey] {
                node = found
            } else {
                node = SkillNode(
                    skillKey: skill.skillKey,
                    category: skill.category.rawValue,
                    cefrLevel: skill.cefrLevel.rawValue,
                    // Навык без предпосылок открыт с самого начала.
                    isUnlocked: skill.prerequisiteKeys.isEmpty
                )
                context.insert(node)
                nodesByKey[skill.skillKey] = node
            }

            let existingLessonIds = Set(node.lessons.map(\.lessonId))
            for (index, lesson) in skill.orderedLessons.enumerated() where !existingLessonIds.contains(lesson.lessonId) {
                // Первый урок навыка доступен сразу, остальные ждут предыдущего.
                let progress = LessonProgress(
                    lessonId: lesson.lessonId,
                    skillKey: skill.skillKey,
                    status: index == 0 ? .available : .locked,
                    skill: node
                )
                context.insert(progress)
                node.lessons.append(progress)
            }
        }

        recalculateUnlocks(nodesByKey: nodesByKey)
        try context.save()
    }

    /// Навык открывается, когда все его предпосылки получили хотя бы одну корону.
    private func recalculateUnlocks(nodesByKey: [String: SkillNode]) {
        for skill in catalog.skills {
            guard let node = nodesByKey[skill.skillKey] else { continue }
            if skill.prerequisiteKeys.isEmpty {
                node.isUnlocked = true
                continue
            }
            let satisfied = skill.prerequisiteKeys.allSatisfy { key in
                (nodesByKey[key]?.masteryLevel ?? 0) >= 1
            }
            if satisfied { node.isUnlocked = true }
        }
    }

    public func skillNode(for key: String) -> SkillNode? {
        let descriptor = FetchDescriptor<SkillNode>(predicate: #Predicate { $0.skillKey == key })
        return try? context.fetch(descriptor).first
    }

    public func lessonProgress(for lessonId: String) -> LessonProgress? {
        let descriptor = FetchDescriptor<LessonProgress>(predicate: #Predicate { $0.lessonId == lessonId })
        return try? context.fetch(descriptor).first
    }

    public func allSkillNodes() -> [SkillNode] {
        (try? context.fetch(FetchDescriptor<SkillNode>())) ?? []
    }

    /// Первый доступный урок навыка — на него ведёт кнопка «Начать».
    public func nextLesson(in skillKey: String) -> LessonContent? {
        guard let skill = catalog.skill(for: skillKey), let node = skillNode(for: skillKey) else { return nil }
        let progressByLesson = Dictionary(node.lessons.map { ($0.lessonId, $0) }, uniquingKeysWith: { first, _ in first })
        return skill.orderedLessons.first { lesson in
            progressByLesson[lesson.lessonId]?.lessonStatus == .available
        } ?? skill.orderedLessons.first
    }

    // MARK: - Применение результата урока

    /// Записывает итог урока: прогресс, XP, монеты, streak, короны, ошибки, карточки SRS.
    public func apply(summary: LessonSummary) {
        didLevelUp = false
        newlyUnlockedAvatars = []
        newlyUnlockedAchievements = []
        refreshDailyCounters()
        let statsBefore = achievementStats()

        let progress = lessonProgress(for: summary.lessonId)
        progress?.attemptsCount += 1
        progress?.bestScore = max(progress?.bestScore ?? 0, summary.scorePercent)

        // Ошибки пишем всегда — они питают разбор и адаптивность.
        if let progress {
            for mistake in summary.mistakes {
                let record = MistakeRecord(
                    itemId: mistake.vocabularyIds.first ?? mistake.exerciseId,
                    questionType: mistake.questionType,
                    prompt: mistake.prompt,
                    userAnswer: mistake.userAnswer,
                    correctAnswer: mistake.correctAnswer,
                    errorCategory: mistake.errorCategory,
                    timestamp: mistake.timestamp,
                    lesson: progress
                )
                context.insert(record)
                progress.mistakesLog.append(record)
            }
        }

        guard summary.isPassed else {
            save()
            return
        }

        // Урок засчитан.
        progress?.lessonStatus = .completed
        progress?.completedAt = summary.completedAt
        unlockNextLesson(after: summary.lessonId, in: summary.skillKey)

        let previousLevel = profile.level
        profile.xpTotal += summary.xpEarned
        profile.todayXP += summary.xpEarned
        profile.coins += summary.coinsEarned
        profile.level = Progression.level(forTotalXP: profile.xpTotal)
        profile.lessonsCompletedTotal += 1
        if summary.isPerfect { profile.perfectLessonsTotal += 1 }
        recordActivity(xp: summary.xpEarned, at: summary.completedAt)

        if let node = skillNode(for: summary.skillKey) {
            node.xpEarned += summary.xpEarned
            node.lastPracticedAt = summary.completedAt
            advanceMasteryIfNeeded(node: node)
        }

        upsertSRSCards(from: summary)

        if profile.todayXP >= profile.dailyGoalXP {
            let state = StreakState(
                count: profile.streakCount,
                freezes: profile.streakFreezes,
                lastActiveDay: profile.streakLastActive
            )
            let (updated, event) = StreakCalculator.registerGoalReached(state, now: now())
            applyStreak(updated)
            lastStreakEvent = event
        }

        if profile.level > previousLevel {
            didLevelUp = true
            newlyUnlockedAvatars = unlockAvatars(forLevel: profile.level, previousLevel: previousLevel)
        }

        // Разблокировка могла измениться из-за новой короны.
        let nodes = Dictionary(allSkillNodes().map { ($0.skillKey, $0) }, uniquingKeysWith: { first, _ in first })
        recalculateUnlocks(nodesByKey: nodes)

        save()
        refreshDueCardsCount()

        // Достижения считаются последними: к этому моменту все счётчики обновлены.
        let statsAfter = achievementStats()
        newlyUnlockedAchievements = AchievementCatalog.newlyUnlocked(before: statsBefore, after: statsAfter)
        syncAchievements(stats: statsAfter)
        save()
    }

    private func unlockNextLesson(after lessonId: String, in skillKey: String) {
        guard let skill = catalog.skill(for: skillKey), let node = skillNode(for: skillKey) else { return }
        let ordered = skill.orderedLessons
        guard let index = ordered.firstIndex(where: { $0.lessonId == lessonId }),
              index + 1 < ordered.count else { return }
        let nextId = ordered[index + 1].lessonId
        if let next = node.lessons.first(where: { $0.lessonId == nextId }), next.lessonStatus == .locked {
            next.lessonStatus = .available
        }
    }

    /// Корона выдаётся за полный круг: все уроки навыка пройдены.
    /// После этого уроки снова становятся доступными для следующего круга.
    private func advanceMasteryIfNeeded(node: SkillNode) {
        guard let skill = catalog.skill(for: node.skillKey) else { return }
        let allCompleted = skill.orderedLessons.allSatisfy { lesson in
            node.lessons.first(where: { $0.lessonId == lesson.lessonId })?.lessonStatus == .completed
        }
        guard allCompleted, node.masteryLevel < GameRules.maxMasteryLevel else { return }

        node.masteryLevel += 1
        if node.masteryLevel < GameRules.maxMasteryLevel {
            for lesson in node.lessons {
                lesson.lessonStatus = .available
            }
        }
        AppLog.persistence.info("Навык \(node.skillKey) получил корону \(node.masteryLevel)")
    }

    private func unlockAvatars(forLevel level: Int, previousLevel: Int) -> [AvatarItem] {
        let newlyAvailable = AvatarCatalog.all.filter {
            if case .level(let required) = $0.unlock {
                return required > previousLevel && required <= level
            }
            return false
        }
        let owned = Set(profile.unlockedAvatars.map(\.avatarId))
        for avatar in newlyAvailable where !owned.contains(avatar.id) {
            let record = UnlockedAvatar(avatarId: avatar.id, unlockedAt: now(), profile: profile)
            context.insert(record)
            profile.unlockedAvatars.append(record)
        }
        return newlyAvailable
    }

    // MARK: - SRS

    /// Создаёт недостающие карточки и обновляет расписание по результатам урока.
    private func upsertSRSCards(from summary: LessonSummary) {
        // Один итог на слово: если слово встретилось несколько раз, берём худший результат.
        var worstOutcome: [String: VocabularyOutcome] = [:]
        for outcome in summary.vocabularyOutcomes {
            if let existing = worstOutcome[outcome.itemId] {
                if existing.isCorrect && !outcome.isCorrect {
                    worstOutcome[outcome.itemId] = outcome
                }
            } else {
                worstOutcome[outcome.itemId] = outcome
            }
        }

        for (itemId, outcome) in worstOutcome {
            guard let vocab = catalog.vocabulary(id: itemId) else { continue }
            let card = existingCard(itemId: itemId) ?? {
                let new = SRSCard(
                    itemId: itemId,
                    word: vocab.word,
                    translation: vocab.translation,
                    nextReviewDate: now(),
                    createdAt: now()
                )
                context.insert(new)
                return new
            }()

            let quality = ReviewQuality.infer(
                isCorrect: outcome.isCorrect,
                responseTime: outcome.responseTime,
                usedHint: outcome.usedHint
            )
            card.apply(SM2Scheduler.schedule(card.state, quality: quality, reviewDate: now()))
        }
    }

    private func existingCard(itemId: String) -> SRSCard? {
        let descriptor = FetchDescriptor<SRSCard>(predicate: #Predicate { $0.itemId == itemId })
        return try? context.fetch(descriptor).first
    }

    /// Карточки, назначенные на сегодня.
    public func dueCards(on date: Date? = nil) -> [SRSCard] {
        let day = Calendar.current.startOfDay(for: date ?? now())
        let end = day.addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<SRSCard>(
            predicate: #Predicate { $0.nextReviewDate < end },
            sortBy: [SortDescriptor(\.nextReviewDate)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Достижения и календарь активности

    /// Снимок счётчиков для расчёта достижений.
    public func achievementStats() -> AchievementStats {
        let nodes = allSkillNodes()
        return AchievementStats(
            streak: profile.streakCount,
            lessonsCompleted: profile.lessonsCompletedTotal,
            perfectLessons: profile.perfectLessonsTotal,
            totalXP: profile.xpTotal,
            wordsLearned: allCards().count,
            crowns: nodes.reduce(0) { $0 + $1.masteryLevel },
            skillsUnlocked: nodes.filter(\.isUnlocked).count
        )
    }

    /// Приводит записи достижений в базе в соответствие с текущими счётчиками.
    public func syncAchievements(stats: AchievementStats? = nil) {
        let stats = stats ?? achievementStats()
        let existing = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        var byKey = Dictionary(existing.map { ($0.achievementKey, $0) }, uniquingKeysWith: { first, _ in first })

        for definition in AchievementCatalog.all {
            let (value, isUnlocked) = AchievementCatalog.progress(for: definition, stats: stats)

            let record: Achievement
            if let found = byKey[definition.id] {
                record = found
            } else {
                record = Achievement(achievementKey: definition.id, progress: 0, target: definition.target)
                context.insert(record)
                byKey[definition.id] = record
            }

            record.progress = value
            record.target = definition.target
            if isUnlocked && record.unlockedAt == nil {
                record.unlockedAt = now()
                AppLog.persistence.info("Достижение открыто: \(definition.id)")
            }
        }
    }

    /// Все достижения с их описаниями — для экрана профиля.
    public func achievements() -> [(definition: AchievementDefinition, record: Achievement?)] {
        let stored = (try? context.fetch(FetchDescriptor<Achievement>())) ?? []
        let byKey = Dictionary(stored.map { ($0.achievementKey, $0) }, uniquingKeysWith: { first, _ in first })
        return AchievementCatalog.all.map { ($0, byKey[$0.id]) }
    }

    /// Отмечает занятие в календаре активности.
    private func recordActivity(xp: Int, at date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        let descriptor = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.day == day })

        if let existing = try? context.fetch(descriptor).first {
            existing.xpEarned += xp
            existing.lessonsCompleted += 1
        } else {
            context.insert(DailyActivity(day: day, xpEarned: xp, lessonsCompleted: 1))
        }
    }

    /// Активность за последние `days` дней: день → набранный XP.
    /// Дни без занятий в словаре отсутствуют — календарь рисует их пустыми.
    public func activityMap(days: Int = 91, endingAt date: Date? = nil) -> [Date: Int] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: date ?? now())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: end) else { return [:] }

        let descriptor = FetchDescriptor<DailyActivity>(predicate: #Predicate { $0.day >= start })
        let records = (try? context.fetch(descriptor)) ?? []
        return Dictionary(records.map { ($0.day, $0.xpEarned) }, uniquingKeysWith: { a, b in a + b })
    }

    private func allCards() -> [SRSCard] {
        (try? context.fetch(FetchDescriptor<SRSCard>())) ?? []
    }

    // MARK: - Аватары

    public func selectAvatar(_ avatarId: String) {
        profile.selectedAvatarId = avatarId
        save()
    }

    public var ownedAvatarIds: Set<String> {
        Set(profile.unlockedAvatars.map(\.avatarId))
    }

    /// Результат попытки купить аватар — экран показывает по нему сообщение.
    public enum AvatarPurchaseResult: Equatable, Sendable {
        case purchased
        case alreadyOwned
        case notPurchasable
        case notEnoughFunds
    }

    /// Покупка косметического аватара за монеты или кристаллы.
    @discardableResult
    public func purchaseAvatar(_ avatarId: String) -> AvatarPurchaseResult {
        guard let avatar = AvatarCatalog.item(id: avatarId) else { return .notPurchasable }
        guard !ownedAvatarIds.contains(avatarId) else { return .alreadyOwned }

        switch avatar.unlock {
        case .default, .level:
            return .notPurchasable
        case .coins(let price):
            guard profile.coins >= price else { return .notEnoughFunds }
            profile.coins -= price
        case .gems(let price):
            guard profile.gems >= price else { return .notEnoughFunds }
            profile.gems -= price
        }

        let record = UnlockedAvatar(avatarId: avatarId, unlockedAt: now(), profile: profile)
        context.insert(record)
        profile.unlockedAvatars.append(record)
        save()
        return .purchased
    }

    // MARK: - Сохранение

    public func save() {
        do {
            try context.save()
        } catch {
            AppLog.persistence.error("Не удалось сохранить контекст: \(error.localizedDescription)")
        }
    }
}
