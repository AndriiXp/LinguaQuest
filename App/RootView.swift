import SwiftUI
import Core
import ContentModels
import Persistence

/// Корневая навигация: вкладки + стек внутри вкладки «Обучение».
struct RootView: View {

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(GameStore.self) private var store

    var body: some View {
        @Bindable var coordinator = coordinator

        TabView(selection: $coordinator.selectedTab) {
            NavigationStack(path: $coordinator.learnPath) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem {
                Label("Обучение", systemImage: "map.fill")
            }
            .tag(AppTab.learn)

            NavigationStack {
                ReviewView()
            }
            .tabItem {
                Label("Повтор", systemImage: "arrow.triangle.2.circlepath")
            }
            .tag(AppTab.review)

            // У профиля собственный стек: иначе push из него уходил бы
            // в стек вкладки «Обучение» и экран открывался бы не там.
            NavigationStack(path: $coordinator.profilePath) {
                ProfileView()
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem {
                Label("Профиль", systemImage: "person.crop.circle.fill")
            }
            .tag(AppTab.profile)
        }
        .tint(DS.Colors.primary)
        .sheet(item: $coordinator.sheet) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear {
            Haptics.isEnabled = store.profile.settings?.hapticsEnabled ?? true
            store.refreshDailyCounters()
            store.refreshStreak()
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .skillDetail(let skillKey):
            SkillDetailView(skillKey: skillKey)
        case .lesson(let lessonId, let skillKey):
            LessonView(lessonId: lessonId, skillKey: skillKey)
        case .settings:
            SettingsView()
        case .avatarGallery:
            AvatarGalleryView()
        }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .dailyGoalPicker:
            NavigationStack { DailyGoalPickerView() }
        }
    }
}
