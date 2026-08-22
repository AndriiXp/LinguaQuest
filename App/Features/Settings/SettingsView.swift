import SwiftUI
import Core
import ContentModels
import Persistence

/// Настройки: звук, уведомления, цель, служебная информация.
struct SettingsView: View {

    @Environment(GameStore.self) private var store
    @Environment(ContentCatalog.self) private var catalog
    @Environment(AppCoordinator.self) private var coordinator

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

            Section("Уведомления") {
                Toggle("Напоминания о занятиях", isOn: remindersBinding)
                Text("Локальные напоминания подключаются в Спринте 4.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
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
                store.save()
            }
        )
    }
}
