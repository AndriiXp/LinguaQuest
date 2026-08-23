#!/usr/bin/env python3
"""Сверяет import-ы в исходниках с зависимостями таргетов в Package.swift.

Забытая зависимость — ошибка, которую видно только компилятору, а он есть
лишь на macOS. Эта проверка ловит её за секунду на любой системе, до CI.

Запуск:  python3 Tools/check_module_deps.py
Код возврата 1 — есть расхождения.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACKAGE = ROOT / "Packages/LinguaQuestKit/Package.swift"
PACKAGE_DIR = PACKAGE.parent

# Модули из SDK и стандартной библиотеки — их объявлять не нужно.
SYSTEM_MODULES = {
    "Foundation", "SwiftUI", "UIKit", "SwiftData", "Observation", "OSLog", "os",
    "Combine", "XCTest", "AVFoundation", "Speech", "UserNotifications",
    "CoreGraphics", "CoreData", "Charts", "StoreKit", "Testing",
}


def parse_targets(source: str) -> dict[str, dict]:
    """Возвращает {имя таргета: {"deps": {...}, "path": "..."}}."""
    targets: dict[str, dict] = {}

    # Каждый .target( / .testTarget( блок до следующего .target на том же уровне.
    for match in re.finditer(r"\.(?:test)?[Tt]arget\(\s*(.*?)\n\s*\)", source, re.S):
        block = match.group(1)

        name_m = re.search(r'name:\s*"([^"]+)"', block)
        if not name_m:
            continue
        name = name_m.group(1)

        deps: set[str] = set()
        deps_m = re.search(r"dependencies:\s*\[(.*?)\]", block, re.S)
        if deps_m:
            deps = set(re.findall(r'"([^"]+)"', deps_m.group(1)))

        path_m = re.search(r'path:\s*"([^"]+)"', block)
        path = path_m.group(1) if path_m else None
        if not path:
            path = f"Tests/{name}" if "Tests" in name else f"Sources/{name}"

        targets[name] = {"deps": deps, "path": path}

    return targets


def imports_in(path: Path) -> dict[str, set[str]]:
    """{имя модуля: {файлы, где он импортируется}}"""
    found: dict[str, set[str]] = {}
    for swift in sorted(path.rglob("*.swift")):
        text = swift.read_text(encoding="utf-8")
        for m in re.finditer(r"^\s*(?:@testable\s+)?import\s+([A-Za-z_][A-Za-z0-9_]*)", text, re.M):
            module = m.group(1)
            found.setdefault(module, set()).add(str(swift.relative_to(ROOT)))
    return found


def main() -> int:
    if not PACKAGE.exists():
        print(f"  ✖  не найден {PACKAGE}")
        return 1

    source = PACKAGE.read_text(encoding="utf-8")
    targets = parse_targets(source)
    if not targets:
        print("  ✖  не удалось разобрать таргеты в Package.swift")
        return 1

    known = set(targets)
    errors: list[str] = []
    warnings: list[str] = []

    for name, info in sorted(targets.items()):
        directory = PACKAGE_DIR / info["path"]
        if not directory.exists():
            errors.append(f"{name}: путь '{info['path']}' не существует")
            continue

        used = imports_in(directory)
        declared = info["deps"]

        # Импортируется, но не объявлено.
        for module, files in sorted(used.items()):
            if module in SYSTEM_MODULES or module == name:
                continue
            if module not in known:
                warnings.append(f"{name}: импортирует неизвестный модуль '{module}' ({sorted(files)[0]})")
                continue
            if module not in declared:
                errors.append(
                    f"{name}: импортирует '{module}', но не объявляет его зависимостью "
                    f"(например {sorted(files)[0]})"
                )

        # Объявлено, но не используется — не ошибка, но лишний вес.
        for module in sorted(declared - set(used)):
            warnings.append(f"{name}: зависимость '{module}' объявлена, но ни один файл её не импортирует")

    for w in warnings:
        print(f"  ⚠  {w}")
    for e in errors:
        print(f"  ✖  {e}")

    if errors:
        print(f"\nНайдено расхождений: {len(errors)}. Поправьте dependencies в Package.swift.")
        return 1

    print(f"Таргетов проверено: {len(targets)}. Зависимости объявлены верно.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
