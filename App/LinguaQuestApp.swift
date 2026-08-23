import SwiftUI
import SwiftData
import Core
import ContentModels
import Persistence
import SpeechKit

@main
struct LinguaQuestApp: App {

    @State private var bootstrap = AppBootstrap()
    @State private var coordinator = AppCoordinator()
    /// Один синтезатор на всё приложение: несколько экземпляров перебивали бы друг друга.
    @State private var speechPlayer = SpeechPlayer()

    var body: some Scene {
        WindowGroup {
            switch bootstrap.state {
            case .loading:
                LoadingScreen()
            case .ready(let container, let store, let catalog):
                RootView()
                    .modelContainer(container)
                    .environment(store)
                    .environment(catalog)
                    .environment(coordinator)
                    .environment(speechPlayer)
            case .failed(let message):
                StartupErrorScreen(message: message) {
                    bootstrap.start()
                }
            }
        }
    }
}

/// Поднимает зависимости приложения: контент → база → игровой стор.
/// Всё синхронно: контент лежит в бандле, база локальная, задержки нет.
@MainActor
@Observable
final class AppBootstrap {

    enum State {
        case loading
        case ready(ModelContainer, GameStore, ContentCatalog)
        case failed(String)
    }

    private(set) var state: State = .loading

    init() {
        start()
    }

    func start() {
        state = .loading
        do {
            let catalog = ContentCatalog()
            try catalog.load()

            let container = try PersistenceController.makeContainer()
            let store = try GameStore(context: container.mainContext, catalog: catalog)

            state = .ready(container, store, catalog)
        } catch {
            AppLog.ui.error("Не удалось запустить приложение: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }
}

private struct LoadingScreen: View {
    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(DS.Colors.primary)
                ProgressView()
            }
        }
    }
}

private struct StartupErrorScreen: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DS.Colors.danger)
                Text("Не удалось запустить приложение")
                    .font(DS.Typography.title)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(message)
                    .font(DS.Typography.callout)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Повторить", action: retry)
                    .buttonStyle(.borderedProminent)
            }
            .padding(DS.Spacing.lg)
        }
    }
}
