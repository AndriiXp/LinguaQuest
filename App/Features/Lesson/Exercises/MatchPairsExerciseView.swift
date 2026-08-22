import SwiftUI
import Core
import ContentModels
import UIComponents

/// Задание на сопоставление: слева слова, справа перемешанные переводы.
/// Пользователь выбирает элемент слева, затем справа — движок сразу проверяет пару.
struct MatchPairsExerciseView: View {

    let exercise: Exercise
    /// Уже верно сопоставленные пары — приходят из сессии.
    let matchedPairIds: Set<String>
    let onSelectPair: (_ pairId: String, _ right: String) -> Void

    @State private var selectedPairId: String?
    @State private var wrongPairId: String?
    /// Порядок правых элементов фиксируется один раз, иначе список
    /// пересобирался бы при каждой перерисовке.
    @State private var shuffledRights: [String] = []

    private var pairs: [MatchPair] { exercise.pairs ?? [] }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            leftColumn
            rightColumn
        }
        .onChange(of: exercise.id, initial: true) { _, _ in
            // Порядок пересобирается при смене задания, а не один раз за жизнь вью,
            // иначе повторно поставленное в очередь задание покажет чужие варианты.
            shuffledRights = pairs.map(\.right).shuffled()
            selectedPairId = nil
            wrongPairId = nil
        }
        .animation(DS.Motion.standard, value: matchedPairIds)
    }

    private var leftColumn: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(pairs) { pair in
                tile(
                    text: pair.left,
                    state: leftState(for: pair),
                    isDone: matchedPairIds.contains(pair.id)
                ) {
                    guard !matchedPairIds.contains(pair.id) else { return }
                    selectedPairId = pair.id
                    wrongPairId = nil
                }
            }
        }
    }

    private var rightColumn: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(shuffledRights, id: \.self) { right in
                let isDone = matchedPairIds.contains { id in
                    pairs.first(where: { $0.id == id })?.right == right
                }
                tile(text: right, state: isDone ? .correct : .idle, isDone: isDone) {
                    guard let selectedPairId, !isDone else { return }
                    handleSelection(pairId: selectedPairId, right: right)
                }
            }
        }
    }

    private func tile(text: String, state: ChoiceState, isDone: Bool, action: @escaping () -> Void) -> some View {
        ChoiceCard(text: text, state: state, action: action)
            .opacity(isDone ? 0.4 : 1)
            .disabled(isDone)
            .frame(maxWidth: .infinity)
    }

    private func leftState(for pair: MatchPair) -> ChoiceState {
        if matchedPairIds.contains(pair.id) { return .correct }
        if wrongPairId == pair.id { return .incorrect }
        if selectedPairId == pair.id { return .selected }
        return .idle
    }

    private func handleSelection(pairId: String, right: String) {
        let expected = pairs.first(where: { $0.id == pairId })?.right
        if expected == right {
            selectedPairId = nil
            wrongPairId = nil
        } else {
            // Подсветка ошибки держится до следующего выбора слева — без таймеров и гонок.
            wrongPairId = pairId
            selectedPairId = nil
        }
        onSelectPair(pairId, right)
    }
}
