import SwiftUI
import Core
import Persistence
import UIComponents

/// Галерея аватаров: доступные, открывающиеся по уровню и покупаемые за валюту.
struct AvatarGalleryView: View {

    @Environment(GameStore.self) private var store

    @State private var pendingPurchase: AvatarItem?
    @State private var purchaseError: String?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: DS.Spacing.md)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
                ForEach(AvatarCatalog.all) { avatar in
                    let available = AvatarCatalog.isAvailable(
                        avatar,
                        level: store.profile.level,
                        ownedIds: store.ownedAvatarIds
                    )

                    VStack(spacing: DS.Spacing.xxs) {
                        AvatarBadge(avatar: avatar, size: 76, isLocked: !available)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        store.profile.selectedAvatarId == avatar.id
                                            ? DS.Colors.primary
                                            : .clear,
                                        lineWidth: 3
                                    )
                            )
                        Text(avatar.title)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(unlockDescription(avatar, available: available))
                            .font(.caption2)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .onTapGesture {
                        handleTap(avatar, available: available)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
        .background(DS.Colors.background)
        .navigationTitle("Аватары")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                StatChip(kind: .coins, value: store.profile.coins)
                StatChip(kind: .gems, value: store.profile.gems)
            }
        }
        .alert(
            "Купить аватар?",
            isPresented: Binding(
                get: { pendingPurchase != nil },
                set: { if !$0 { pendingPurchase = nil } }
            ),
            presenting: pendingPurchase
        ) { avatar in
            Button("Купить за \(priceText(avatar))") {
                confirmPurchase(avatar)
                pendingPurchase = nil
            }
            Button("Отмена", role: .cancel) { pendingPurchase = nil }
        } message: { avatar in
            Text("«\(avatar.title)» станет доступен навсегда.")
        }
        .alert(
            "Не получилось",
            isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "")
        }
    }

    /// Доступный аватар выбирается, покупаемый — предлагается к покупке,
    /// уровневый просто сообщает, чего не хватает.
    private func handleTap(_ avatar: AvatarItem, available: Bool) {
        if available {
            Haptics.selection()
            store.selectAvatar(avatar.id)
            return
        }

        switch avatar.unlock {
        case .coins, .gems:
            pendingPurchase = avatar
        case .default, .level:
            Haptics.error()
        }
    }

    private func confirmPurchase(_ avatar: AvatarItem) {
        switch store.purchaseAvatar(avatar.id) {
        case .purchased:
            Haptics.success()
            store.selectAvatar(avatar.id)
        case .notEnoughFunds:
            Haptics.error()
            purchaseError = "Не хватает валюты для этого аватара."
        case .alreadyOwned:
            store.selectAvatar(avatar.id)
        case .notPurchasable:
            Haptics.error()
            purchaseError = "Этот аватар нельзя купить."
        }
    }

    private func priceText(_ avatar: AvatarItem) -> String {
        switch avatar.unlock {
        case .coins(let value): return "\(value) монет"
        case .gems(let value): return "\(value) кристаллов"
        default: return ""
        }
    }

    private func unlockDescription(_ avatar: AvatarItem, available: Bool) -> String {
        if available { return store.profile.selectedAvatarId == avatar.id ? "Выбран" : "Доступен" }
        switch avatar.unlock {
        case .default: return "Доступен"
        case .level(let value): return "С уровня \(value)"
        case .coins(let value): return "\(value) монет"
        case .gems(let value): return "\(value) кристаллов"
        }
    }
}

/// Выбор дневной цели.
struct DailyGoalPickerView: View {

    @Environment(GameStore.self) private var store
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        List {
            ForEach(GameRules.DailyGoal.allCases, id: \.rawValue) { goal in
                Button {
                    store.profile.dailyGoalXP = goal.xp
                    store.save()
                    coordinator.dismissSheet()
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(title(for: goal))
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("\(goal.xp) XP в день")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }
                        Spacer()
                        if store.profile.dailyGoalXP == goal.xp {
                            Image(systemName: "checkmark")
                                .foregroundStyle(DS.Colors.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Дневная цель")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func title(for goal: GameRules.DailyGoal) -> String {
        switch goal {
        case .casual: return "Спокойный"
        case .regular: return "Обычный"
        case .serious: return "Серьёзный"
        }
    }
}
