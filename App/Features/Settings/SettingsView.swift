import SwiftUI
import Core
import ContentModels
import Persistence

/// Настройки: звук, уведомления, цель, служебная информация.
struct SettingsView: View {

    @Environment(GameStore.self) private var store
    @Environment(ContentCatalog.self) private var catalog
    @Environment(AppCoordinator.self) private var coordinator

    @State private var scheduler = ReminderScheduler()
    @State private var permissionDenied = false

    var body: some View {
        Form {
            Section("Игра") {
                Button {
                    coordinator.present(.dailyGoalPicker)
                } label: {
                    LabeledContent("Дневная цель", value: "\(store.profile.dailyGoalXP) XP")
                }

                LabeledContent("Уровень", value: "\(store.profile.level)")
                LabeledContent("Серия дней", value: "\(store.profile.streakCount)")
                LabeledContent("Заморозки", value: "\(store.profile.streakFreezes)")
            }

            Section("Звук и отклик") {
                Toggle("Звук", isOn: soundBinding)
                Toggle("Вибрация", isOn: hapticsBinding)
            }

            Section("Напоминания") {
                Toggle("Напоминать о занятиях", isOn: remindersBinding)

                if store.profile.settings?.dailyReminderEnabled == true {
                    DatePicker(
                        "Время",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                if permissionDenied {
                    Text("Уведомления запрещены в системных настройках. Включите их в Настройках → LinguaQuest → Уведомления.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.danger)
                } else {
                    Text("Одно напоминание в день и предупреждение вечером, если серия под угрозой.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }

            Section("О приложении") {
                LabeledContent("Версия контента", value: "\(catalog.contentVersion)")
                LabeledContent("Навыков в каталоге", value: "\(catalog.skills.count)")
                if !catalog.validationIssues.isEmpty {
                    NavigationLink("Замечания к контенту (\(catalog.validationIssues.count))") {
                        List(catalog.validationIssues, id: \.self) { issue in
                            Text(issue)
                                .font(DS.Typography.caption)
                        }
                        .navigationTitle("Контент")
                    }
                }
                Text("Фаза 1: всё работает офлайн, данные хранятся только на устройстве.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Пользователь мог отключить уведомления в системных настройках
            // уже после того, как включил их здесь — проверяем при каждом открытии.
            let status = await scheduler.authorizationStatus()
            permissionDenied = status == .denied
        }
    }

    // MARK: - Напоминания

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { store.profile.settings?.reminderTime ?? ReminderScheduler.defaultTime() },
            set: { newValue in
                store.profile.settings?.reminderTime = newValue
                store.save()
                Task { await rescheduleReminders() }
            }
        )
    }

    private func rescheduleReminders() async {
        guard store.profile.settings?.dailyReminderEnabled == true else {
            scheduler.cancelAll()
            return
        }

        let granted = await scheduler.requestAuthorization()
        guard granted else {
            permissionDenied = true
            store.profile.settings?.dailyReminderEnabled = false
            store.save()
            return
        }
        permissionDenied = false

        let time = store.profile.settings?.reminderTime ?? ReminderScheduler.defaultTime()
        await scheduler.scheduleDaily(
            at: ReminderScheduler.components(from: time),
            streak: store.profile.streakCount
        )
        await scheduler.scheduleStreakWarning(
            streak: store.profile.streakCount,
            goalReached: store.profile.todayXP >= store.profile.dailyGoalXP
        )
    }

    // MARK: - Привязки к настройкам

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { store.profile.settings?.soundEnabled ?? true },
            set: { newValue in
                store.profile.settings?.soundEnabled = newValue
                store.save()
            }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { store.profile.settings?.hapticsEnabled ?? true },
            set: { newValue in
                store.profile.settings?.hapticsEnabled = newValue
                Haptics.isEnabled = newValue
                store.save()
            }
        )
    }

    private var remindersBinding: Binding<Bool> {
        Binding(
            get: { store.profile.settings?.dailyReminderEnabled ?? false },
            set: { newValue in
                store.profile.settings?.dailyReminderEnabled = newValue
                if newValue && store.profile.settings?.reminderTime == nil {
                    store.profile.settings?.reminderTime = ReminderScheduler.defaultTime()
                }
                store.save()
                Task { await rescheduleReminders() }
            }
        )
    }
}
