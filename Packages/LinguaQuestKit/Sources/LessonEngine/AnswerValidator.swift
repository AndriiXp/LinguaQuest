import Foundation

/// Результат сверки ответа с эталоном.
public enum AnswerMatch: Equatable, Sendable {
    /// Точное совпадение после нормализации.
    case exact
    /// Отличие в одну опечатку — засчитываем, но показываем правильное написание.
    case typo(correct: String)
    /// Не совпало.
    case wrong
}

/// Сверка пользовательского ввода с эталонными ответами.
///
/// Нормализация намеренно снисходительна: регистр, лишние пробелы, финальная
/// пунктуация и вид апострофа не должны отнимать сердце у изучающего A1.
public enum AnswerValidator {

    /// Приводит строку к канонической форме для сравнения.
    public static func normalize(_ raw: String) -> String {
        var text = raw.lowercased()

        // Разные виды апострофов и кавычек — к прямому апострофу.
        let apostrophes: [Character] = ["\u{2019}", "\u{02BC}", "\u{00B4}", "`"]
        text = String(text.map { apostrophes.contains($0) ? "'" : $0 })

        // Убираем пунктуацию (внутри слов апостроф и дефис сохраняем).
        text = String(text.filter { char in
            char.isLetter || char.isNumber || char.isWhitespace || char == "'" || char == "-"
        })

        // Схлопываем пробелы.
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ")
    }

    /// Сверяет ответ с набором допустимых вариантов.
    /// - Parameter allowTypos: разрешить одну опечатку (для ввода текстом; для выбора из вариантов — нет).
    public static func match(
        input: String,
        against accepted: [String],
        allowTypos: Bool = true
    ) -> AnswerMatch {
        let normalizedInput = normalize(input)
        guard !normalizedInput.isEmpty else { return .wrong }

        for candidate in accepted where normalize(candidate) == normalizedInput {
            return .exact
        }

        guard allowTypos else { return .wrong }

        for candidate in accepted {
            let normalizedCandidate = normalize(candidate)
            // Опечатки прощаем только в достаточно длинных ответах:
            // в коротких словах одна буква меняет смысл (he/we, in/on).
            guard normalizedCandidate.count >= 5 else { continue }
            // Разница длин — нижняя граница расстояния: если она больше порога,
            // полную матрицу считать незачем.
            guard abs(normalizedCandidate.count - normalizedInput.count) <= 1 else { continue }
            if levenshtein(normalizedInput, normalizedCandidate) <= 1 {
                return .typo(correct: candidate)
            }
        }

        return .wrong
    }

    /// Расстояние Левенштейна между строками (итеративный вариант с одной строкой памяти).
    public static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,        // удаление
                    current[j - 1] + 1,     // вставка
                    previous[j - 1] + cost  // замена
                )
            }
            previous = current
        }
        return previous[b.count]
    }
}
