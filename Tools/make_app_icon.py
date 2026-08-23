#!/usr/bin/env python3
"""Рисует иконку приложения LinguaQuest.

Иконка генерируется кодом, а не хранится как чужой ассет: цвета берутся
из тех же значений, что DesignTokens.swift, и правятся в одном месте.

Знак: речевое облако (язык, общение) со ступенями внутри (прогресс, дерево
навыков) — два смысла продукта в одной форме, читаемой на 40 px.

Требования Apple: 1024×1024, PNG, БЕЗ альфа-канала, без собственных скруглений —
маску системы Xcode накладывает сам.

Запуск:  python3 Tools/make_app_icon.py
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "App/Assets.xcassets/AppIcon.appiconset"
SIZE = 1024
SS = 4  # суперсэмплинг: рисуем крупнее и уменьшаем, чтобы края были гладкими

# DS.Colors.primary и его светлый оттенок из DesignTokens.swift
TOP = (124, 106, 245)
BOTTOM = (91, 74, 214)
WHITE = (255, 255, 255)


def vertical_gradient(size: int, top: tuple, bottom: tuple) -> Image.Image:
    """Диагональный градиент — как у LinearGradient(topLeading → bottomTrailing)."""
    base = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(base)
    for y in range(size):
        t = y / (size - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return base


def rounded_rect(draw: ImageDraw.ImageDraw, box, radius: int, fill) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def build(size: int) -> Image.Image:
    s = size * SS
    img = vertical_gradient(s, TOP, BOTTOM)
    draw = ImageDraw.Draw(img)

    # Мягкое световое пятно сверху слева — иконка не выглядит плоской.
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gdraw = ImageDraw.Draw(glow)
    gdraw.ellipse([-s * 0.25, -s * 0.45, s * 0.75, s * 0.35], fill=(255, 255, 255, 26))
    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
    draw = ImageDraw.Draw(img)

    # Речевое облако.
    bx0, by0 = s * 0.20, s * 0.215
    bx1, by1 = s * 0.80, s * 0.685
    rounded_rect(draw, [bx0, by0, bx1, by1], radius=int(s * 0.115), fill=WHITE)

    # Хвостик облака — треугольник со скруглением у основания.
    tail = [
        (s * 0.335, by1 - s * 0.01),
        (s * 0.475, by1 - s * 0.01),
        (s * 0.360, s * 0.825),
    ]
    draw.polygon(tail, fill=WHITE)

    # Ступени прогресса внутри облака: три столбика разной высоты.
    bar_w = s * 0.088
    gap = s * 0.052
    base_y = s * 0.585
    heights = [s * 0.115, s * 0.185, s * 0.255]
    total_w = bar_w * 3 + gap * 2
    start_x = (s - total_w) / 2

    for i, h in enumerate(heights):
        x0 = start_x + i * (bar_w + gap)
        y0 = base_y - h
        # Цвет столбиков — фон, поэтому они «вырезаны» из облака.
        color = tuple(round(TOP[j] + (BOTTOM[j] - TOP[j]) * (y0 / s)) for j in range(3))
        rounded_rect(draw, [x0, y0, x0 + bar_w, base_y], radius=int(bar_w * 0.42), fill=color)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    icon = build(SIZE)

    # Строго RGB: альфа-канал в иконке — причина отказа при загрузке в App Store.
    assert icon.mode == "RGB", icon.mode
    path = OUT_DIR / "AppIcon-1024.png"
    icon.save(path, "PNG", optimize=True)

    contents = """{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
    (OUT_DIR / "Contents.json").write_text(contents, encoding="utf-8")

    # Превью для проверки на мелком размере — в репозиторий не попадает.
    preview = Image.new("RGB", (SIZE, 260), (246, 247, 251))
    x = 24
    for s in (180, 120, 80, 60, 40):
        preview.paste(icon.resize((s, s), Image.LANCZOS), (x, 40))
        x += s + 24
    preview.save("/tmp/icon-preview.png")

    print(f"Иконка: {path.relative_to(ROOT)}  {icon.size[0]}×{icon.size[1]}  режим {icon.mode}")
    print("Превью размеров: /tmp/icon-preview.png")


if __name__ == "__main__":
    main()
