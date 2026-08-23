import SwiftUI
import Core
import ContentModels
import UIComponents

/// Задание «собери предложение»: слова лежат внизу вперемешку,
/// нажатие переносит слово в строку ответа и обратно.
struct WordOrderExerciseView: View {

    let exercise: Exercise
    /// Собранное предложение — читает и меняет экран урока.
    @Binding var chosen: [String]
    let isLocked: Bool

    /// Порядок в «банке слов» фиксируется один раз за показ задания:
    /// иначе слова прыгали бы при каждой перерисовке.
    @State private var bank: [Token] = []

    /// Слово с собственным идентификатором: в предложении бывают повторы
    /// («I read books every day» с двумя одинаковыми словами), и по тексту их не различить.
    private struct Token: Identifiable, Equatable {
        let id: Int
        let text: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            answerArea
            bankArea
        }
        .onChange(of: exercise.id, initial: true) { _, _ in
            bank = (exercise.tokens ?? [])
                .shuffled()
                .enumerated()
                .map { Token(id: $0.offset, text: $0.element) }
            chosen = []
        }
    }

    // MARK: - Строка ответа

    private var answerArea: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            FlowLayout(spacing: DS.Spacing.xs) {
                ForEach(Array(chosen.enumerated()), id: \.offset) { index, word in
                    Button {
                        guard !isLocked else { return }
                        Haptics.light()
                        returnToBank(at: index)
                    } label: {
                        tokenLabel(word, filled: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .topLeading)
            .padding(DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Colors.border, lineWidth: 1)
            )

            if chosen.isEmpty {
                Text("Нажимайте слова внизу, чтобы собрать предложение")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
        }
    }

    // MARK: - Банк слов

    private var bankArea: some View {
        FlowLayout(spacing: DS.Spacing.xs) {
            ForEach(bank) { token in
                Button {
                    guard !isLocked else { return }
                    Haptics.light()
                    take(token)
                } label: {
                    tokenLabel(token.text, filled: false)
                }
                .buttonStyle(.plain)
                .disabled(isLocked)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(DS.Motion.quick, value: bank)
    }

    private func tokenLabel(_ text: String, filled: Bool) -> some View {
        Text(text)
            .font(DS.Typography.body)
            .foregroundStyle(DS.Colors.textPrimary)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xs)
            .frame(minHeight: DS.Size.minTapTarget)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(filled ? DS.Colors.primarySoft : DS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .strokeBorder(filled ? DS.Colors.primary : DS.Colors.border, lineWidth: 1)
            )
    }

    // MARK: - Перекладывание слов

    private func take(_ token: Token) {
        bank.removeAll { $0.id == token.id }
        chosen.append(token.text)
    }

    private func returnToBank(at index: Int) {
        guard chosen.indices.contains(index) else { return }
        let word = chosen.remove(at: index)
        // Новый id больше всех прежних — не столкнётся с оставшимися в банке.
        let nextId = (bank.map(\.id).max() ?? -1) + 1
        bank.append(Token(id: nextId, text: word))
    }
}

/// Раскладка «в строку с переносом»: SwiftUI не умеет этого из коробки,
/// а слова предложения обязаны переноситься по ширине экрана.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: maxWidth == .infinity ? rows.map(\.width).max() ?? 0 : maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width

            if needed > maxWidth && !current.indices.isEmpty {
                rows.append(current)
                current = Row()
                current.indices = [index]
                current.width = size.width
                current.height = size.height
            } else {
                current.indices.append(index)
                current.width = needed
                current.height = max(current.height, size.height)
            }
        }

        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
