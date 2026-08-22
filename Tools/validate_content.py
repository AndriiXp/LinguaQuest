#!/usr/bin/env python3
"""Валидатор учебного контента LinguaQuest.

Повторяет правила Exercise.validationError() и ContentCatalog.load() из Swift,
чтобы ошибки в JSON находились до сборки на Mac, а не в рантайме на устройстве.

Запуск:  python3 Tools/validate_content.py
Код возврата 1 — есть ошибки.
"""

import json
import sys
from pathlib import Path

CONTENT_DIR = Path(__file__).resolve().parent.parent / \
    "Packages/LinguaQuestKit/Sources/ContentModels/Resources/Content"

IMPLEMENTED_TYPES = {"multiple_choice", "type_answer", "match_pairs"}
KNOWN_TYPES = IMPLEMENTED_TYPES | {"word_order", "fill_blank", "listening", "speaking"}
CEFR = {"A1", "A2", "B1", "B2", "C1", "C2"}
CATEGORIES = {"grammar", "vocab", "listening", "speaking"}

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load(name: str):
    path = CONTENT_DIR / f"{name}.json"
    if not path.exists():
        err(f"файл не найден: {path.name}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        err(f"{path.name}: некорректный JSON — {e}")
        return None


def validate_exercise(ex: dict, lesson_id: str, vocab_ids: set[str]) -> None:
    ref = f"{lesson_id}/{ex.get('id', '???')}"

    for field in ("id", "type", "prompt"):
        if not ex.get(field):
            err(f"{ref}: отсутствует обязательное поле '{field}'")
            return

    ex_type = ex["type"]
    if ex_type not in KNOWN_TYPES:
        err(f"{ref}: неизвестный тип задания '{ex_type}'")
        return
    if ex_type not in IMPLEMENTED_TYPES:
        warn(f"{ref}: тип '{ex_type}' пока не реализован — задание будет отфильтровано")

    if ex_type in ("multiple_choice", "listening"):
        options = ex.get("options") or []
        if len(options) < 2:
            err(f"{ref}: нужно минимум 2 варианта ответа")
        if not ex.get("correctAnswer"):
            err(f"{ref}: не задан correctAnswer")
        elif ex["correctAnswer"] not in options:
            err(f"{ref}: correctAnswer '{ex['correctAnswer']}' отсутствует среди options")
        if len(set(options)) != len(options):
            err(f"{ref}: варианты ответа дублируются")

    elif ex_type in ("type_answer", "speaking"):
        if not ex.get("correctAnswer"):
            err(f"{ref}: не задан correctAnswer")

    elif ex_type == "fill_blank":
        if not ex.get("correctAnswer"):
            err(f"{ref}: не задан correctAnswer")
        if "___" not in ex["prompt"]:
            err(f"{ref}: в prompt нет маркера пропуска ___")

    elif ex_type == "match_pairs":
        pairs = ex.get("pairs") or []
        if len(pairs) < 2:
            err(f"{ref}: нужно минимум 2 пары")
        ids = [p.get("id") for p in pairs]
        rights = [p.get("right") for p in pairs]
        lefts = [p.get("left") for p in pairs]
        if len(set(ids)) != len(ids):
            err(f"{ref}: id пар дублируются")
        if len(set(rights)) != len(rights):
            err(f"{ref}: правые части дублируются — сопоставление станет неоднозначным")
        if len(set(lefts)) != len(lefts):
            err(f"{ref}: левые части дублируются")
        for p in pairs:
            if not p.get("left") or not p.get("right"):
                err(f"{ref}: пара {p.get('id')} заполнена не полностью")

    elif ex_type == "word_order":
        tokens = ex.get("tokens") or []
        if len(tokens) < 2:
            err(f"{ref}: нужно минимум 2 слова")
        if not ex.get("correctAnswer"):
            err(f"{ref}: не задан correctAnswer")

    difficulty = ex.get("difficulty", 1)
    if not isinstance(difficulty, int) or not 1 <= difficulty <= 3:
        err(f"{ref}: difficulty должен быть 1..3, получено {difficulty!r}")

    for vid in ex.get("vocabularyIds") or []:
        if vid not in vocab_ids:
            err(f"{ref}: ссылка на несуществующее слово '{vid}'")


def main() -> int:
    manifest = load("manifest")
    if manifest is None:
        print_report()
        return 1

    vocab = load(manifest["vocabularyFile"]) or []
    vocab_ids: set[str] = set()
    for item in vocab:
        item_id = item.get("itemId")
        if not item_id:
            err("vocabulary: запись без itemId")
            continue
        if item_id in vocab_ids:
            err(f"vocabulary: дубликат itemId '{item_id}'")
        vocab_ids.add(item_id)
        for field in ("word", "translation", "cefrLevel"):
            if not item.get(field):
                err(f"vocabulary/{item_id}: пустое поле '{field}'")
        if item.get("cefrLevel") not in CEFR:
            err(f"vocabulary/{item_id}: неизвестный уровень '{item.get('cefrLevel')}'")

    skill_keys: set[str] = set()
    prerequisites: dict[str, list[str]] = {}
    lesson_ids: set[str] = set()
    exercise_ids: set[str] = set()
    used_vocab: set[str] = set()
    total_exercises = 0

    for file_name in manifest["skillFiles"]:
        skill = load(file_name)
        if skill is None:
            continue

        key = skill.get("skillKey")
        if not key:
            err(f"{file_name}: отсутствует skillKey")
            continue
        if key in skill_keys:
            err(f"{file_name}: дубликат skillKey '{key}'")
        skill_keys.add(key)
        prerequisites[key] = skill.get("prerequisiteKeys") or []

        if skill.get("cefrLevel") not in CEFR:
            err(f"{key}: неизвестный уровень '{skill.get('cefrLevel')}'")
        if skill.get("category") not in CATEGORIES:
            err(f"{key}: неизвестная категория '{skill.get('category')}'")
        if not skill.get("iconName"):
            err(f"{key}: пустой iconName")
        if not skill.get("sourceStandard"):
            warn(f"{key}: не указан sourceStandard — нужен для аудита происхождения контента")

        lessons = skill.get("lessons") or []
        if not lessons:
            err(f"{key}: нет уроков")
        orders = [lesson.get("orderIndex") for lesson in lessons]
        if len(set(orders)) != len(orders):
            err(f"{key}: orderIndex уроков дублируется")

        for lesson in lessons:
            lesson_id = lesson.get("lessonId")
            if not lesson_id:
                err(f"{key}: урок без lessonId")
                continue
            if lesson_id in lesson_ids:
                err(f"{key}: дубликат lessonId '{lesson_id}'")
            lesson_ids.add(lesson_id)

            if not lesson.get("title"):
                err(f"{lesson_id}: пустой title")
            if not isinstance(lesson.get("xpReward"), int) or lesson["xpReward"] <= 0:
                err(f"{lesson_id}: xpReward должен быть положительным числом")

            exercises = lesson.get("exercises") or []
            if len(exercises) < 4:
                warn(f"{lesson_id}: всего {len(exercises)} заданий — урок будет очень коротким")

            implemented = [e for e in exercises if e.get("type") in IMPLEMENTED_TYPES]
            if not implemented:
                err(f"{lesson_id}: не осталось ни одного реализованного задания — урок не откроется")

            for ex in exercises:
                total_exercises += 1
                ex_key = f"{lesson_id}/{ex.get('id')}"
                if ex_key in exercise_ids:
                    err(f"{lesson_id}: дубликат id задания '{ex.get('id')}'")
                exercise_ids.add(ex_key)
                validate_exercise(ex, lesson_id, vocab_ids)
                used_vocab.update(ex.get("vocabularyIds") or [])

    for key, prereqs in prerequisites.items():
        for prereq in prereqs:
            if prereq not in skill_keys:
                err(f"{key}: prerequisite '{prereq}' отсутствует в каталоге")
            if prereq == key:
                err(f"{key}: навык указан собственной предпосылкой")

    roots = [k for k, p in prerequisites.items() if not p]
    if not roots:
        err("в дереве навыков нет ни одного корневого узла — прогресс невозможно начать")

    # Поиск цикла в графе предпосылок.
    visiting: set[str] = set()
    visited: set[str] = set()

    def has_cycle(node: str) -> bool:
        if node in visiting:
            return True
        if node in visited:
            return False
        visiting.add(node)
        for parent in prerequisites.get(node, []):
            if parent in prerequisites and has_cycle(parent):
                return True
        visiting.discard(node)
        visited.add(node)
        return False

    for key in prerequisites:
        if has_cycle(key):
            err(f"цикл в предпосылках вокруг навыка '{key}'")
            break

    unused = vocab_ids - used_vocab
    if unused:
        warn(f"слова не используются ни в одном задании ({len(unused)}): {', '.join(sorted(unused))}")

    print(f"Навыков: {len(skill_keys)}  уроков: {len(lesson_ids)}  заданий: {total_exercises}  слов: {len(vocab_ids)}")
    print_report()
    return 1 if errors else 0


def print_report() -> None:
    for w in warnings:
        print(f"  ⚠  {w}")
    for e in errors:
        print(f"  ✖  {e}")
    if not errors:
        print("Контент валиден." if not warnings else "Контент валиден (есть замечания).")


if __name__ == "__main__":
    sys.exit(main())
