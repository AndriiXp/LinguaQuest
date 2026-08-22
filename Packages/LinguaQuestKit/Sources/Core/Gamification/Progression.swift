import Foundation

/// Кривая прокачки персонажа: перевод суммарного XP в уровень и обратно.
///
/// Стоимость уровня растёт линейно: L-й уровень стоит `50 * (L - 1)` XP,
/// поэтому суммарный XP до уровня L равен `25 * L * (L - 1)`.
/// Уровень 1 = 0 XP, 2 = 50, 3 = 150, 4 = 300, 5 = 500 ...
public enum Progression {

    public static let baseStep = 50

    /// Суммарный XP, необходимый чтобы ДОСТИЧЬ уровня `level`.
    public static func totalXP(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        return baseStep * level * (level - 1) / 2
    }

    /// Уровень персонажа при данном суммарном XP. Минимум — 1.
    public static func level(forTotalXP xp: Int) -> Int {
        guard xp > 0 else { return 1 }
        // Решение 25*L*(L-1) <= xp относительно L.
        let discriminant = 1.0 + 4.0 * Double(xp) / Double(baseStep) * 2.0
        var level = Int((1.0 + discriminant.squareRoot()) / 2.0)
        // Страховка от погрешности Double на больших значениях.
        while totalXP(forLevel: level + 1) <= xp { level += 1 }
        while level > 1 && totalXP(forLevel: level) > xp { level -= 1 }
        return level
    }

    /// XP, набранный внутри текущего уровня.
    public static func xpInCurrentLevel(totalXP xp: Int) -> Int {
        max(0, xp - totalXP(forLevel: level(forTotalXP: xp)))
    }

    /// Сколько XP нужно набрать внутри текущего уровня, чтобы перейти на следующий.
    public static func xpNeededForNextLevel(totalXP xp: Int) -> Int {
        let current = level(forTotalXP: xp)
        return totalXP(forLevel: current + 1) - totalXP(forLevel: current)
    }

    /// Прогресс внутри уровня в диапазоне 0...1 — для полосы XP.
    public static func levelProgress(totalXP xp: Int) -> Double {
        let needed = xpNeededForNextLevel(totalXP: xp)
        guard needed > 0 else { return 0 }
        return min(1, max(0, Double(xpInCurrentLevel(totalXP: xp)) / Double(needed)))
    }
}
