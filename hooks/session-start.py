#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SessionStart: положить в контекст, где проект остановился.

GUIDE советует начинать сессию с /bpd:status. Совет исполняется, пока о нём
помнят, а после /clear и месяца перерыва не помнит никто. Хук кладёт то же
самое сам — три строки из STATE.md, не пересказывая и ничего не вычисляя.

Проценты и статусы этапов здесь намеренно не считаются: их дом — /bpd:status,
и второй считающий разошёлся бы с первым.
"""

from __future__ import annotations

import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _common import (  # noqa: E402
    МЕТКА, прочитать_событие, проект, сказать, сломался, это_bpd_проект,
)

СОБЫТИЕ = "SessionStart"
ПОЛЯ = ("Последняя сессия", "Остановились на", "Следующий шаг")


def main() -> None:
    событие = прочитать_событие()
    корень = проект(событие)
    if not это_bpd_проект(корень):
        return  # Не BPD-проект — молчим.

    состояние = os.path.join(корень, МЕТКА, "STATE.md")
    if not os.path.isfile(состояние):
        сказать(СОБЫТИЕ,
                "В проекте есть .bpd/, но нет .bpd/STATE.md — после /clear "
                "не за что зацепиться. Восстановить: /bpd:status")
        return

    try:
        with open(состояние, encoding="utf-8") as ф:
            текст = ф.read()
    except (OSError, UnicodeDecodeError) as беда:
        сказать(СОБЫТИЕ, f"Не прочитать .bpd/STATE.md ({беда}). "
                         f"Состояние проекта в этой сессии неизвестно.")
        return

    строки = []
    for поле in ПОЛЯ:
        найдено = re.search(rf"\*\*{re.escape(поле)}:\*\*\s*(.+)", текст)
        if найдено and найдено.group(1).strip():
            строки.append(f"{поле}: {найдено.group(1).strip()}")

    if not строки:
        return  # Файл есть, но продолжать не с чего — навязываться незачем.

    сказать(СОБЫТИЕ,
            "Проект ведётся фреймворком BPD. Из .bpd/STATE.md:\n"
            + "\n".join(f"• {с}" for с in строки)
            + "\nПодробнее — /bpd:status. Правки в .bpd/ делать командами /bpd:*, "
              "а не руками.")


if __name__ == "__main__":
    try:
        main()
    except Exception as беда:  # noqa: BLE001 — тихо умирать хук не вправе
        сломался(__file__, беда, СОБЫТИЕ)
    sys.exit(0)
