# ТЗ: Мобильное приложение для изучения английского в игровой форме (iOS)

**Кодовое имя проекта:** `LinguaQuest` (рабочее, можно менять)
**Платформа:** iOS 17+
**Формат:** нативное приложение (Swift / SwiftUI)
**Цель документа:** передача в Claude Code для поэтапной разработки

---

## 1. Обзор продукта

Приложение для изучения английского языка с RPG-механикой прогрессии. Пользователь прокачивает "языкового персонажа" через уроки, разбитые по навыкам (лексика, грамматика, аудирование, произношение). Ключевые отличия от Duolingo:

- **RPG-дерево навыков** вместо линейного пути — пользователь сам выбирает, что качать
- **Адаптивный контент через Claude API** — упражнения генерируются под персональные ошибки пользователя
- **SRS (интервальный повтор)** для долгосрочного запоминания лексики
- **Проверка произношения** через Apple Speech framework

### Целевая аудитория
- Уровни CEFR: A1 → B2 (на старте), C1-C2 в перспективе
- Взрослые и подростки, изучающие английский самостоятельно
- Гео на старте: русскоязычный интерфейс + английский контент (позже — мультиязычный UI)

### Стратегия разработки: две фазы

**Фаза 1 — «для себя» (dev / TestFlight):**
Всё локально, без бэкенда. Цель — быстро получить рабочий прототип и проверить механику на своём устройстве.
- Без Firebase, без модерации, без монетизации, без соц-фич
- Хранение только в SwiftData
- Контент генерируется через Claude заранее и кладётся в JSON-файлы (bundled в приложение)
- Аватар — только локальный, без загрузки на сервер (модерация не нужна, пока нет публичности)

**Фаза 2 — подготовка к App Store:**
Подключаются все «облачные» и обязательные для стора модули.
- Firebase (Auth, Firestore, синхронизация)
- Модерация пользовательского аватара (**обязательно для ревью Apple**)
- Монетизация (StoreKit), лиги, лидерборды
- Политика приватности, App Privacy labels, механизм жалоб на UGC

> Каждый спринт ниже помечен фазой. Модули Фазы 2 спроектированы заранее, но реализуются только перед выходом в стор.

---

## 2. Технологический стек

| Слой | Технология | Обоснование |
|------|-----------|-------------|
| UI | SwiftUI | Нативно, быстрая разработка, анимации |
| Игровые сцены | SpriteKit (опционально, фаза 3) | Карта прогресса, анимации персонажа |
| Локальное хранилище | SwiftData | Прогресс, SRS-расписание, офлайн |
| Backend | Firebase (Auth + Firestore + Cloud Functions) | Быстрый старт для соло-разработчика |
| Речь (распознавание) | Apple Speech framework | Встроенный, бесплатный |
| TTS (озвучка) | AVSpeechSynthesizer + опц. ElevenLabs | Озвучка слов/диалогов |
| AI-контент | Anthropic Claude API (через Cloud Function) | Генерация адаптивных упражнений, объяснений |
| Аналитика | Firebase Analytics + Crashlytics | Метрики и краши |
| Монетизация | StoreKit 2 | Подписки и IAP |

> **Важно:** Claude API вызывается **только через Cloud Function**, ключ никогда не хранится в приложении.

### Архитектурный паттерн
- **MVVM** + Coordinator для навигации
- Модульная структура (Swift Packages): `Core`, `LessonEngine`, `SRSEngine`, `UIComponents`, `Networking`, `ContentModels`
- Разделение учебного **контента** и **кода**: контент версионируется в Firestore/JSON, чтобы обновлять уроки без релиза

---

## 3. Схема базы данных

### 3.1 Локальная БД (SwiftData) — прогресс и офлайн

```
UserProfile
├── id: UUID
├── displayName: String
├── currentCEFR: String            // "A1", "A2"...
├── xpTotal: Int
├── level: Int                     // уровень персонажа
├── coins: Int
├── gems: Int
├── streakCount: Int
├── streakLastActive: Date
├── streakFreezes: Int
├── dailyGoalXP: Int               // цель XP в день
├── createdAt: Date
├── selectedAvatarId: String        // выбранный аватар из набора
└── settings: UserSettings (relationship)

UserSettings
├── id: UUID
├── soundEnabled: Bool
├── notificationsEnabled: Bool
├── reminderTime: Date?
├── interfaceLanguage: String      // "ru", "en"
└── dailyReminderEnabled: Bool

SkillNode                          // узел дерева навыков
├── id: UUID
├── skillKey: String               // "present_simple", "food_vocab"
├── category: String               // "grammar", "vocab", "listening", "speaking"
├── cefrLevel: String
├── title: String
├── iconName: String
├── prerequisiteKeys: [String]     // что нужно открыть до
├── isUnlocked: Bool
├── masteryLevel: Int              // 0-5 (crown levels)
├── xpEarned: Int
└── lessons: [LessonProgress] (relationship)

LessonProgress
├── id: UUID
├── lessonId: String               // ссылка на контент
├── skillKey: String
├── status: String                 // "locked","available","completed"
├── bestScore: Int                 // %
├── attemptsCount: Int
├── completedAt: Date?
└── mistakesLog: [MistakeRecord] (relationship)

MistakeRecord                      // для адаптивности + аналитики ошибок
├── id: UUID
├── itemId: String                 // ID слова/грамматич. правила
├── questionType: String
├── userAnswer: String
├── correctAnswer: String
├── timestamp: Date
└── errorCategory: String          // "spelling","word_order","tense"...

SRSCard                            // карточка интервального повтора
├── id: UUID
├── itemId: String                 // ID лексической единицы
├── word: String
├── translation: String
├── easeFactor: Double             // SM-2, старт 2.5
├── intervalDays: Int
├── repetitions: Int
├── nextReviewDate: Date
├── lastReviewedAt: Date?
└── lapses: Int

Achievement
├── id: UUID
├── achievementKey: String
├── unlockedAt: Date?
└── progress: Int                  // для прогрессивных ачивок
```

### 3.2 Облачная БД (Firestore) — контент, соц. фичи, синхронизация

```
/users/{userId}
    ├── profile (mirror локального UserProfile для синка)
    ├── xpTotal, level, currentLeague, weeklyXP
    └── /progress/{skillKey}        // подколлекция синхронизации прогресса

/content/{cefrLevel}/skills/{skillKey}
    ├── title, category, iconName
    ├── prerequisiteKeys: []
    └── /lessons/{lessonId}
            ├── title
            ├── orderIndex
            ├── xpReward
            └── exercises: [        // массив заданий
                  {
                    id, type,       // "multiple_choice","type_answer",
                                    // "listening","speaking","match_pairs",
                                    // "word_order","fill_blank"
                    prompt,
                    correctAnswer,
                    options: [],
                    audioUrl,
                    hint,
                    difficulty
                  }
                ]

/vocabulary/{itemId}                // словарная база для SRS
    ├── word, translation
    ├── partOfSpeech
    ├── cefrLevel
    ├── exampleSentence
    ├── audioUrl
    └── imageUrl

/leagues/{leagueId}/participants/{userId}
    ├── displayName, weeklyXP, avatarId
    └── rank

/leaderboards/weekly/{weekId}/entries/{userId}

/config/appConfig                   // remote config (лимиты, цены, версии контента)
```

---

## 4. Экраны приложения

### 4.1 Onboarding Flow
| Экран | Описание |
|-------|----------|
| Splash | Логотип, загрузка, проверка авторизации |
| Welcome | Слайды с ценностным предложением (3-4 экрана) |
| Goal Selection | Выбор цели: путешествия / работа / экзамен / общее |
| Placement Test | Адаптивный тест уровня (10-15 вопросов), определяет стартовый CEFR |
| Daily Goal | Выбор ежедневной цели (Casual 10 XP / Regular 20 / Serious 50) |
| Auth | Sign in with Apple / Email (можно отложить, гостевой режим) |

### 4.2 Основные экраны
| Экран | Ключевые элементы |
|-------|-------------------|
| **Home / Skill Tree** | Дерево навыков с узлами, текущий уровень, streak-счётчик, полоса XP, кнопка "Практика/Повтор" |
| **Lesson** | Движок заданий: прогресс-бар, задание, поле ответа, feedback (правильно/ошибка), кнопка проверки, система "жизней" |
| **Lesson Complete** | Итог: заработанные XP, монеты, streak, breakdown по ошибкам, кнопка "Продолжить" |
| **Review (SRS)** | Сессия повторения карточек, назначенных на сегодня |
| **Profile** | Персонаж/аватар, статистика (streak, всего слов, точность), календарь активности, ачивки |
| **Leaderboard** | Еженедельная лига, ранг пользователя, список участников |
| **Shop** | Покупка бустеров, заморозок streak, косметики за монеты/gems + IAP |
| **Settings** | Язык интерфейса, уведомления, звук, подписка, аккаунт |
| **Paywall** | Экран подписки (показывается по триггерам) |

### 4.3 Типы заданий (Lesson Engine)
1. **Multiple choice** — выбор перевода/значения
2. **Type answer** — ввод перевода текстом
3. **Match pairs** — сопоставление слово ↔ перевод
4. **Word order** — собрать предложение из слов
5. **Fill in the blank** — вставить пропущенное слово/форму
6. **Listening** — прослушать и выбрать/напечатать
7. **Speaking** — произнести фразу, проверка через Speech framework

---

## 5. Ключевые алгоритмы

### 5.1 SRS (алгоритм SM-2, упрощённый)
```
При ответе на карточку оценка quality (0-5):
  - Если quality < 3 (ошибка):
      repetitions = 0
      intervalDays = 1
      lapses += 1
  - Иначе:
      если repetitions == 0: intervalDays = 1
      если repetitions == 1: intervalDays = 6
      иначе: intervalDays = round(intervalDays * easeFactor)
      repetitions += 1
  easeFactor = max(1.3, easeFactor + (0.1 - (5-quality)*(0.08 + (5-quality)*0.02)))
  nextReviewDate = today + intervalDays
```

### 5.2 Адаптивная генерация (Claude API через Cloud Function) — Фаза 2
- Триггер: после N ошибок в определённой категории (`errorCategory`)
- Cloud Function собирает контекст (последние ошибки пользователя) и запрашивает у Claude API дополнительные упражнения на слабую тему
- Результат кэшируется в Firestore, отдаётся в приложение
- **Fallback:** если API недоступен — статичный банк упражнений (из bundled JSON)

### 5.3 Streak-логика
- Streak увеличивается при выполнении дневной цели XP
- Пропуск дня → сброс, если нет `streakFreeze`
- Заморозка тратится автоматически при пропуске

---

## 5A. Генерация учебного контента (Фаза 1 — dev-время)

> **Важно по копирайту.** Контент **не копируется** из учебников и защищённых источников. Claude генерирует **оригинальные** упражнения и объяснения, опираясь на **открытые стандарты и методологию**, а не на конкретные тексты книг. Копирование предложений/упражнений из Murphy, Cambridge coursebooks и т.п. недопустимо и юридически, и практически.

### Легальные источники-ориентиры (открытые стандарты)
| Источник | Что даёт | Статус |
|----------|----------|--------|
| **CEFR Companion Volume** (Council of Europe) | Официальные дескрипторы уровней A1-C2, «can-do» формулировки | Открытый документ |
| **Oxford 3000 / 5000** | Частотный список ядровой лексики по уровням | Открытый список слов |
| **NGSL** (New General Service List) | ~2800 самых частотных слов, покрывающих ~92% текста | Открытая лицензия |
| **English Grammar Profile / English Vocabulary Profile** | Что усваивается на каждом уровне | Открытые ресурсы Cambridge |

### Пайплайн генерации (выполняется на этапе разработки, не в рантайме Фазы 1)
```
1. Взять CEFR-дескриптор темы (например A1: "Present Simple, повседневная рутина")
2. Взять срез частотного списка под уровень (Oxford 3000 / NGSL)
3. Промпт Claude: сгенерировать N оригинальных упражнений
   по заданной структуре и прогрессии сложности
4. Валидация 2-м проходом Claude (проверка уровня, корректности, дублей)
5. Ручная вычитка разработчиком
6. Экспорт в JSON → bundled в приложение (Фаза 1)
   позже → загрузка в Firestore (Фаза 2)
```

### Структура сгенерированного JSON (пример)
```json
{
  "skillKey": "present_simple_a1",
  "cefrLevel": "A1",
  "sourceStandard": "CEFR Companion + Oxford 3000",
  "lessons": [
    {
      "lessonId": "ps_a1_l1",
      "xpReward": 20,
      "exercises": [
        {
          "id": "e1",
          "type": "multiple_choice",
          "prompt": "She ___ coffee every morning.",
          "correctAnswer": "drinks",
          "options": ["drink", "drinks", "drinking"],
          "hint": "3rd person singular",
          "difficulty": 1
        }
      ]
    }
  ]
}
```

---

## 5B. Аватары персонажа (стандартный набор)

> Загрузка пользовательских картинок **отложена** на будущее (потребует модерации UGC по Guideline 1.2 Apple). На старте — только готовый набор аватаров из ассетов приложения. Это убирает модерацию, ускоряет ревью и упрощает код.

### Набор аватаров
- Готовые изображения в ассетах: эмодзи-стиль, животные, стилизованные персонажи (наборы по темам)
- Хранятся локально (bundled), не требуют сети
- У каждого аватара — `avatarId`, категория, условие разблокировки

### Условия получения
| Способ | Детали |
|--------|--------|
| Стартовый набор | Несколько базовых аватаров доступны сразу |
| Разблокировка по уровню | Открываются при достижении уровня персонажа |
| Покупка за монеты / gems | Косметические аватары в магазине (Shop) |

### Модель данных (добавить в схему)
```
AvatarItem
├── avatarId: String
├── category: String          // "animals", "emoji", "characters"
├── assetName: String         // имя в Assets.xcassets
├── unlockType: String        // "default", "level", "purchase"
├── unlockLevel: Int?         // если unlockType == "level"
├── priceCoins: Int?          // если покупается за монеты
└── priceGems: Int?           // если покупается за gems

UserProfile.selectedAvatarId: String   // добавить поле в UserProfile
UserOwnedAvatars                       // какие аватары разблокированы
├── avatarId: String
└── unlockedAt: Date
```

> Будущая фича «загрузить свою картинку» проектируется отдельным модулем позже, когда появится готовность строить модерационный слой (Vision framework + серверная модерация + EXIF-очистка + жалобы).

---

## 6. Монетизация

| Модель | Детали |
|--------|--------|
| Freemium | Система "жизней" (5 сердец), восстановление по времени или за gems |
| Premium (подписка) | Безлимит жизней, офлайн-режим, детальная аналитика ошибок, без рекламы |
| IAP разовые | Косметические аватары (из набора), бустеры XP, наборы заморозок |
| Триггеры paywall | После потери всех жизней, на 3-й день streak, при попытке офлайн-режима |

Цены и лимиты — через Firebase Remote Config (`/config/appConfig`), без релиза.

---

## 7. Бэклог по спринтам

> Спринт ≈ 2 недели. Ориентир для соло-разработки с Claude Code.
> **Фаза 1** = «для себя» (локально, TestFlight). **Фаза 2** = подготовка к App Store.

### 🟢 ФАЗА 1 — прототип для себя

#### Спринт 0 — Фундамент (Фаза 1)
- [ ] Настройка проекта Xcode, структура Swift Packages
- [ ] Базовая навигация (Coordinator), тема оформления, дизайн-токены
- [ ] Модели SwiftData (UserProfile, SkillNode, LessonProgress, SRSCard, AvatarItem)
- [ ] Гостевой профиль + локальное сохранение
- [ ] (Firebase НЕ подключаем в этой фазе)

#### Спринт 1 — Ядро уроков (MVP-прототип) (Фаза 1)
- [ ] Lesson Engine: рендер заданий из **bundled JSON** (не из сети)
- [ ] Типы заданий: multiple_choice, type_answer, match_pairs
- [ ] Экран Lesson + Lesson Complete
- [ ] Система жизней (локально)
- [ ] Контент 1 навыка A1, сгенерированный через Claude (см. раздел 5A)

#### Спринт 2 — Дерево навыков и прогрессия (Фаза 1)
- [ ] Home / Skill Tree UI с узлами и разблокировкой
- [ ] Логика XP, уровней персонажа, mastery (crowns)
- [ ] Streak-механика + дневная цель
- [ ] Экран Profile со статистикой
- [ ] Стандартные аватары: выбор, разблокировка по уровню (см. раздел 5B)
- [ ] Локальные ачивки

#### Спринт 3 — SRS и остальные задания (Фаза 1)
- [ ] SRSEngine (SM-2), генерация карточек из пройденной лексики
- [ ] Экран Review, назначение карточек на день
- [ ] Задания: word_order, fill_blank
- [ ] Логирование ошибок (MistakeRecord)

#### Спринт 4 — Аудио и произношение (Фаза 1)
- [ ] TTS-озвучка (AVSpeechSynthesizer)
- [ ] Listening-задания
- [ ] Speaking-задания через Speech framework + оценка
- [ ] Локальные уведомления (напоминания о streak)
- [ ] Наполнение контентом A1 (полные навыки), генерация через Claude

> **К концу Фазы 1** у тебя рабочее приложение на своём устройстве: уроки, дерево, SRS, аудио, стандартные аватары, всё офлайн. Можно тестировать механику вживую.

---

### 🔵 ФАЗА 2 — подготовка к App Store

#### Спринт 5 — Backend и синхронизация (Фаза 2)
- [ ] Подключение Firebase (Auth, Firestore, Analytics, Crashlytics)
- [ ] Sign in with Apple, миграция гостевого прогресса в аккаунт
- [ ] Синхронизация прогресса локально ↔ Firestore
- [ ] Перенос контента из bundled JSON в Firestore (версионирование)
- [ ] Наполнение контентом A2 (полные уровни)

#### Спринт 6 — Соц. фичи (Фаза 2)
- [ ] Лиги и еженедельные лидерборды (Cloud Functions)
- [ ] Экран Leaderboard
- [ ] Онбординг: placement test, goal selection, daily goal

#### Спринт 7 — AI-адаптивность в рантайме (Фаза 2)
- [ ] Cloud Function для вызова Claude API (ключ только на сервере)
- [ ] Адаптивная генерация упражнений по слабым темам пользователя
- [ ] Кэширование сгенерированного контента в Firestore
- [ ] Fallback-логика (при недоступности API — bundled банк)

#### Спринт 8 — Монетизация и релиз (Фаза 2)
- [ ] StoreKit 2: подписка + IAP
- [ ] Экраны Shop и Paywall, триггеры
- [ ] Покупка косметических аватаров за монеты/gems
- [ ] Remote Config для цен/лимитов
- [ ] Политика приватности, App Privacy labels, ATT
- [ ] Полировка, тесты, подготовка к App Store (скриншоты, метаданные)

> Загрузка пользовательских аватаров (с модерацией) — **отдельный будущий модуль**, вне этого roadmap.

---

## 8. Нефункциональные требования

- **Офлайн-режим:** уроки и SRS работают без сети, синк при подключении
- **Производительность:** запуск < 2 сек, плавные анимации 60 fps
- **Безопасность:** API-ключи только в Cloud Functions; данные пользователя — по правилам Firestore Security Rules
- **Локализация:** UI строки через `String Catalog` (Localizable), старт — ru + en
- **Доступность:** поддержка Dynamic Type, VoiceOver для основных экранов
- **Приватность:** согласие на аналитику, App Tracking Transparency

---

## 9. Решённые вопросы и что осталось

**Решено:**
1. ✅ **Аватары** — стандартный набор (эмодзи/животные/персонажи), разблокировка по уровню или покупка. Загрузка своих картинок — отложена в отдельный будущий модуль.
2. ✅ **Контент** — генерируется через Claude на этапе разработки, с опорой на открытые стандарты (CEFR, Oxford 3000, NGSL), без копирования учебников. См. раздел 5A.
3. ✅ **Стратегия** — сначала Фаза 1 «для себя» (локально, TestFlight), затем Фаза 2 (стор).

**Осталось уточнить:**
1. Backend в Фазе 2: точно Firebase или рассмотреть Supabase (Postgres)?
2. Формат стандартных аватаров: свои иллюстрации (можно сгенерировать) или готовый икон-сет?
3. Нужна ли подписка сразу в Фазе 2 или монетизацию отложить и на первый релиз выйти бесплатным?

---

*Документ подготовлен для хендоффа в Claude Code. Начинать рекомендуется со Спринта 0.*
