#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fix-typography.py - детерминированные замены типографики, Этап 2.

Меняет только то, где замена однозначна и контекст не нужен:

  —  U+2014 длинное тире          → дефис
  –  U+2013 короткое тире         → дефис
  …  U+2026 многоточие символом   → три точки
  “ ” U+201C/201D                 → « »
  ‘ ’ U+2018/2019                 → прямой апостроф
  U+00A0 неразрывный пробел       → обычный пробел
  U+200B/200C/200D/FEFF/2028/2029 → удалить
  \\.  \\-  \\!  \\*  экранирование  → снять

Блоки кода (``` … ```), строчный код (` … `) и HTML-теги не трогает: там
длинное тире и кавычки бывают частью кода.

Смысл текста не меняется ни в одном символе. Всё, что требует чтения смысла,
делают следующие этапы, не этот скрипт.

Использование:
  python3 tools/fix-typography.py текст.md            # вывод в stdout
  python3 tools/fix-typography.py текст.md --in-place  # правка файла
  python3 tools/fix-typography.py текст.md --report    # только счётчик замен

Коды выхода: 0 - готово, 3 - ошибка ввода.
"""
import argparse
import re
import sys

REPLACEMENTS = [
    ("\u2014", "-", "длинное тире"),
    ("\u2013", "-", "короткое тире"),
    ("\u2026", "...", "многоточие одним символом"),
    ("\u201c", "\u00ab", "левая типографская кавычка"),
    ("\u201d", "\u00bb", "правая типографская кавычка"),
    ("\u2018", "'", "левый типографский апостроф"),
    ("\u2019", "'", "правый типографский апостроф"),
    ("\u00a0", " ", "неразрывный пробел"),
    ("\u200b", "", "пробел нулевой ширины"),
    ("\u200c", "", "несоединитель нулевой ширины"),
    ("\u200d", "", "соединитель нулевой ширины"),
    ("\ufeff", "", "метка порядка байтов"),
    ("\u2028", "\n", "разделитель строк"),
    ("\u2029", "\n\n", "разделитель абзацев"),
]

ESCAPE_RE = re.compile(r"\\([.!\-*])")
PROTECTED = re.compile(r"```.*?```|`[^`\n]*`|<[^>\n]+>", re.DOTALL)


def transform(chunk, stats):
    for src, dst, name in REPLACEMENTS:
        c = chunk.count(src)
        if c:
            stats[name] = stats.get(name, 0) + c
            chunk = chunk.replace(src, dst)
    c = len(ESCAPE_RE.findall(chunk))
    if c:
        stats["лишнее экранирование"] = stats.get("лишнее экранирование", 0) + c
        chunk = ESCAPE_RE.sub(r"\1", chunk)
    return chunk


def process(raw):
    stats = {}
    out, pos = [], 0
    for m in PROTECTED.finditer(raw):
        out.append(transform(raw[pos:m.start()], stats))
        out.append(m.group(0))
        pos = m.end()
    out.append(transform(raw[pos:], stats))
    return "".join(out), stats


def main():
    ap = argparse.ArgumentParser(
        prog="fix-typography.py",
        description="Однозначные замены типографики. Смысл текста не трогает, "
                    "блоки кода пропускает.")
    ap.add_argument("path", help="файл, либо - для чтения из stdin")
    ap.add_argument("--in-place", action="store_true", help="переписать файл на месте")
    ap.add_argument("--report", action="store_true", help="напечатать только счётчик замен")
    args = ap.parse_args()

    try:
        raw = sys.stdin.read() if args.path == "-" else open(
            args.path, encoding="utf-8").read()
    except OSError as e:
        sys.stderr.write("ошибка чтения: %s\n" % e)
        sys.exit(3)

    fixed, stats = process(raw)

    if args.report:
        if not stats:
            print("замен нет")
        for name, c in sorted(stats.items(), key=lambda x: -x[1]):
            print("%-34s ×%d" % (name, c))
        sys.exit(0)

    if args.in_place:
        if args.path == "-":
            sys.stderr.write("--in-place не работает со stdin\n")
            sys.exit(3)
        with open(args.path, "w", encoding="utf-8") as f:
            f.write(fixed)
        total = sum(stats.values())
        sys.stderr.write("заменено %d символов в %s\n" % (total, args.path))
        for name, c in sorted(stats.items(), key=lambda x: -x[1]):
            sys.stderr.write("  %-34s ×%d\n" % (name, c))
    else:
        sys.stdout.write(fixed)
    sys.exit(0)


if __name__ == "__main__":
    main()
