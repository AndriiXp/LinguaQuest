#!/usr/bin/env python3
"""Референсная реализация алгоритмов LinguaQuest + самопроверка.

Swift-код невозможно скомпилировать вне macOS, поэтому формулы (SM-2, кривая
уровней, регенерация сердец, подсчёт итога урока, расстояние Левенштейна)
продублированы здесь один-в-один и прогоняются тестами. Ожидаемые значения
из этого файла перенесены в XCTest-тесты пакета — так расхождение между
Python-эталоном и Swift обнаружится на первой же сборке на Mac.

Запуск: python3 Tools/reference_algorithms.py
"""

import math
import sys
import unittest

# ---------------------------------------------------------------- Progression

BASE_STEP = 50


def total_xp_for_level(level: int) -> int:
    if level <= 1:
        return 0
    return BASE_STEP * level * (level - 1) // 2


def level_for_total_xp(xp: int) -> int:
    if xp <= 0:
        return 1
    discriminant = 1.0 + 4.0 * xp / BASE_STEP * 2.0
    level = int((1.0 + math.sqrt(discriminant)) / 2.0)
    while total_xp_for_level(level + 1) <= xp:
        level += 1
    while level > 1 and total_xp_for_level(level) > xp:
        level -= 1
    return level


# -------------------------------------------------------------------- SM-2

MIN_EASE = 1.3
MAX_INTERVAL = 365


def sm2(ease: float, interval: int, repetitions: int, lapses: int, quality: int):
    if quality < 3:
        repetitions = 0
        interval = 1
        lapses += 1
    else:
        if repetitions == 0:
            interval = 1
        elif repetitions == 1:
            interval = 6
        else:
            interval = min(MAX_INTERVAL, round(interval * ease))
        repetitions += 1

    delta = 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)
    ease = max(MIN_EASE, ease + delta)
    interval = max(1, interval)
    return ease, interval, repetitions, lapses


# ------------------------------------------------------------------- Hearts

MAX_HEARTS = 5
REGEN_MINUTES = 30


def hearts_now(stored: int, minutes_since_spent: float | None) -> int:
    if stored >= MAX_HEARTS or minutes_since_spent is None:
        return stored
    if minutes_since_spent <= 0:
        return stored
    return min(MAX_HEARTS, stored + int(minutes_since_spent) // REGEN_MINUTES)


# ------------------------------------------------------- Итог урока

XP_PER_CORRECT = 2
PERFECT_XP_BONUS = 10
COINS_PER_LESSON = 5
PERFECT_COINS_BONUS = 3
PASSING_SCORE = 60


def lesson_summary(total: int, correct: int, mistakes: int, xp_reward: int, ran_out: bool):
    score = round(correct / total * 100) if total else 0
    perfect = mistakes == 0 and correct == total and total > 0
    passed = (not ran_out) and score >= PASSING_SCORE

    xp = coins = 0
    if passed:
        xp = xp_reward + correct * XP_PER_CORRECT
        coins = COINS_PER_LESSON
        if perfect:
            xp += PERFECT_XP_BONUS
            coins += PERFECT_COINS_BONUS
    return {"score": score, "perfect": perfect, "passed": passed, "xp": xp, "coins": coins}


# -------------------------------------------------------------- Левенштейн

def levenshtein(a: str, b: str) -> int:
    if not a:
        return len(b)
    if not b:
        return len(a)
    previous = list(range(len(b) + 1))
    for i in range(1, len(a) + 1):
        current = [i] + [0] * len(b)
        for j in range(1, len(b) + 1):
            cost = 0 if a[i - 1] == b[j - 1] else 1
            current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
        previous = current
    return previous[len(b)]


def normalize(raw: str) -> str:
    text = raw.lower()
    for ch in ("’", "ʼ", "´", "`"):
        text = text.replace(ch, "'")
    kept = [c for c in text if c.isalnum() or c.isspace() or c in ("'", "-")]
    return " ".join("".join(kept).split())


def match(user: str, accepted: list[str], allow_typos: bool = True) -> str:
    normalized = normalize(user)
    if not normalized:
        return "wrong"
    if any(normalize(c) == normalized for c in accepted):
        return "exact"
    if not allow_typos:
        return "wrong"
    for candidate in accepted:
        nc = normalize(candidate)
        if len(nc) >= 5 and levenshtein(normalized, nc) <= 1:
            return "typo"
    return "wrong"


# ------------------------------------------------------------------ Тесты

class ProgressionTests(unittest.TestCase):
    def test_thresholds(self):
        self.assertEqual([total_xp_for_level(n) for n in range(1, 7)], [0, 50, 150, 300, 500, 750])

    def test_level_lookup(self):
        # 100 000 XP: 25*63*62 = 97 650 <= 100 000 < 25*64*63 = 100 800 → уровень 63.
        cases = {0: 1, 49: 1, 50: 2, 149: 2, 150: 3, 299: 3, 300: 4, 500: 5, 100_000: 63}
        for xp, expected in cases.items():
            self.assertEqual(level_for_total_xp(xp), expected, f"xp={xp}")

    def test_monotonic_and_consistent(self):
        previous = 1
        for xp in range(0, 20_000, 7):
            level = level_for_total_xp(xp)
            self.assertGreaterEqual(level, previous)
            self.assertLessEqual(total_xp_for_level(level), xp)
            self.assertGreater(total_xp_for_level(level + 1), xp)
            previous = level


class SM2Tests(unittest.TestCase):
    def test_first_success(self):
        ease, interval, reps, lapses = sm2(2.5, 0, 0, 0, 5)
        self.assertEqual((interval, reps, lapses), (1, 1, 0))
        self.assertAlmostEqual(ease, 2.6)

    def test_second_success(self):
        ease, interval, reps, _ = sm2(2.6, 1, 1, 0, 4)
        self.assertEqual((interval, reps), (6, 2))
        self.assertAlmostEqual(ease, 2.6)

    def test_third_success_uses_ease(self):
        ease, interval, reps, _ = sm2(2.6, 6, 2, 0, 4)
        self.assertEqual((interval, reps), (16, 3))  # round(6 * 2.6) = 16

    def test_failure_resets(self):
        ease, interval, reps, lapses = sm2(2.5, 16, 3, 0, 1)
        self.assertEqual((interval, reps, lapses), (1, 0, 1))
        self.assertAlmostEqual(ease, 1.96)

    def test_ease_floor(self):
        ease = 2.5
        interval, reps, lapses = 10, 3, 0
        for _ in range(12):
            ease, interval, reps, lapses = sm2(ease, interval, reps, lapses, 0)
        self.assertEqual(ease, MIN_EASE)

    def test_interval_cap(self):
        ease, interval, reps = 2.5, 300, 5
        _, interval, _, _ = sm2(ease, interval, reps, 0, 5)
        self.assertEqual(interval, MAX_INTERVAL)


class HeartsTests(unittest.TestCase):
    def test_no_regen_when_full(self):
        self.assertEqual(hearts_now(5, 600), 5)

    def test_partial_regen(self):
        self.assertEqual(hearts_now(2, 29), 2)
        self.assertEqual(hearts_now(2, 30), 3)
        self.assertEqual(hearts_now(2, 61), 4)
        self.assertEqual(hearts_now(0, 600), 5)

    def test_never_exceeds_max(self):
        self.assertEqual(hearts_now(4, 10_000), 5)


class LessonSummaryTests(unittest.TestCase):
    def test_perfect_run(self):
        result = lesson_summary(total=7, correct=7, mistakes=0, xp_reward=20, ran_out=False)
        self.assertEqual(result, {"score": 100, "perfect": True, "passed": True, "xp": 44, "coins": 8})

    def test_passing_with_mistakes(self):
        result = lesson_summary(total=7, correct=5, mistakes=2, xp_reward=20, ran_out=False)
        self.assertEqual(result["score"], 71)
        self.assertTrue(result["passed"])
        self.assertFalse(result["perfect"])
        self.assertEqual(result["xp"], 30)
        self.assertEqual(result["coins"], 5)

    def test_below_passing_score(self):
        result = lesson_summary(total=7, correct=3, mistakes=4, xp_reward=20, ran_out=False)
        self.assertEqual(result["score"], 43)
        self.assertFalse(result["passed"])
        self.assertEqual(result["xp"], 0)

    def test_out_of_hearts_gives_nothing(self):
        result = lesson_summary(total=7, correct=7, mistakes=0, xp_reward=20, ran_out=True)
        self.assertFalse(result["passed"])
        self.assertEqual((result["xp"], result["coins"]), (0, 0))


class AnswerMatchingTests(unittest.TestCase):
    def test_case_and_punctuation(self):
        self.assertEqual(match("  Drinks. ", ["drinks"]), "exact")
        self.assertEqual(match("I don't work", ["I do not work", "I don't work"]), "exact")

    def test_curly_apostrophe(self):
        self.assertEqual(match("I don’t work", ["I don't work"]), "exact")

    def test_typo_allowed_in_long_words(self):
        self.assertEqual(match("breakfost", ["breakfast"]), "typo")

    def test_typo_rejected_in_short_words(self):
        self.assertEqual(match("he", ["we"]), "wrong")
        self.assertEqual(match("cat", ["cot"]), "wrong")

    def test_choice_mode_has_no_typo_tolerance(self):
        self.assertEqual(match("breakfost", ["breakfast"], allow_typos=False), "wrong")

    def test_empty_input(self):
        self.assertEqual(match("   ", ["water"]), "wrong")


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=2).result
    sys.exit(0 if result.wasSuccessful() else 1)
