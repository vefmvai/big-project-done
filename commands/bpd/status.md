---
name: bpd:status
description: Показать текущий прогресс проекта
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---
<objective>
Показать сводку по проекту: прогресс, список этапов, текущая позиция, следующий шаг.
Только чтение — ничего не меняет.
</objective>

<execution_context>
@$HOME_DIR/.claude/bpd/workflows/status.md
</execution_context>

<process>
Выполни workflow из @$HOME_DIR/.claude/bpd/workflows/status.md.
Покажи только результат — без лишних комментариев.
</process>
