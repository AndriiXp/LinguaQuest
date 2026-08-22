import Foundation
import SwiftUI

/// Экраны, на которые можно уйти push-переходом внутри основной вкладки.
public enum AppRoute: Hashable, Sendable {
    case skillDetail(skillKey: String)
    case lesson(lessonId: String, skillKey: String)
    case settings
    case avatarGallery
}

/// Экраны, которые показываются модально поверх всего.
public enum AppSheet: Identifiable, Hashable, Sendable {
    case dailyGoalPicker

    public var id: Self { self }
}

/// Вкладки приложения. У каждой свой стек навигации — иначе push из профиля
/// уезжал бы в стек обучения и визуально «ничего не происходило».
public enum AppTab: String, Hashable, CaseIterable, Sendable {
    case learn
    case review
    case profile
}

/// Координатор навигации: экраны не знают друг о друге, они просят координатор о переходе.
@Observable
public final class AppCoordinator {
    public var selectedTab: AppTab = .learn
    public var learnPath = NavigationPath()
    public var profilePath = NavigationPath()
    public var sheet: AppSheet?

    public init() {}

    /// Стек активной вкладки. Вкладка «Повтор» пока показывает один экран
    /// и делит стек с обучением — когда у неё появится своя навигация,
    /// сюда добавится третий путь.
    public var path: NavigationPath {
        get {
            switch selectedTab {
            case .learn, .review: return learnPath
            case .profile: return profilePath
            }
        }
        set {
            switch selectedTab {
            case .learn, .review: learnPath = newValue
            case .profile: profilePath = newValue
            }
        }
    }

    public func push(_ route: AppRoute) {
        path.append(route)
    }

    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    public func popToRoot() {
        switch selectedTab {
        case .learn, .review: learnPath = NavigationPath()
        case .profile: profilePath = NavigationPath()
        }
    }

    public func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    public func dismissSheet() {
        sheet = nil
    }
}
