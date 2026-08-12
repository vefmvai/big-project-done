#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Общий дом для двух хуков BPD: как говорить в контекст и как падать.

Оба ответа вынесены сюда не ради экономии строк, а потому что это правила,
а не удобства: хук обязан говорить одинаково, и обязан сознаваться в
собственной поломке. Две копии этих правил разошлись бы.
"""

from __future__ import annotations

import json
import os
import sys

МЕТКА = ".bpd"


def проект(событие: dict) -> str:
    """Корень проекта: сначала то, что дал Claude Code, потом текущая папка."""
    return os.environ.get("CLAUDE_PROJECT_DIR") or событие.get("cwd") or os.getcwd()


def это_bpd_проект(корень: str) -> bool:
    """Ворота хука.

    Проверяем именно папку. В loreground был баг, когда `mkdir` вместо файла
    глушил половину сторожей: тип объекта никто не проверял.
    """
    return os.path.isdir(os.path.join(корень, МЕТКА))


def прочитать_событие() -> dict:
    """Событие с stdin. Не разобрали — молчим: своей вины у проекта тут нет."""
    try:
        сырое = sys.stdin.read()
    except (OSError, ValueError):
        return {}
    if not сырое.strip():
        return {}
    try:
        разобрано = json.loads(сырое)
    except json.JSONDecodeError:
        return {}
    return разобрано if isinstance(разобрано, dict) else {}


def сказать(событие: str, текст: str) -> None:
    """Отдать хозяину сессии одну порцию контекста. Выход — за вызывающим."""
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        экранировать = False
    except (AttributeError, ValueError, OSError):
        экранировать = True
    json.dump(
        {"hookSpecificOutput": {"hookEventName": событие, "additionalContext": текст}},
        sys.stdout,
        ensure_ascii=экранировать,
    )
    sys.stdout.write("\n")


def сломался(имя: str, беда: Exception, событие: str) -> None:
    """Хук обязан сознаться, что не отработал.

    Молчание хука по его же устройству значит «всё хорошо» — поэтому тихо
    умереть он права не имеет. Код возврата всегда 0: сорвать работу
    инструмента из-за собственной поломки хук тоже не вправе.
    """
    команда = f'{sys.executable} "{os.path.abspath(имя)}"'
    сказать(
        событие,
        f"Хук {os.path.basename(имя)} не отработал — "
        f"{type(беда).__name__}: {беда}. "
        f"Проверка BPD в этой сессии не выполнялась; это не «всё чисто». "
        f"Прогнать вручную: {команда}",
    )
