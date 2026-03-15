---
name: bpd:check
description: Проверить результат этапа по чеклисту качества
argument-hint: "[номер этапа]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---
<objective>
Проверить что результат этапа соответствует плану и критериям качества.
Автоматическая проверка + ручная проверка пользователем.

Без аргумента — проверяет последний выполненный непроверенный этап.
С номером — проверяет конкретный.

Итог: Принято → следующий этап, или Доработать → повторить `/bpd:do`.
</objective>

<execution_context>
@$HOME_DIR/.claude/bpd/workflows/check.md
@$HOME_DIR/.claude/bpd/templates/CHECK.md
</execution_context>

<context>
Номер этапа: $ARGUMENTS (необязательно)
</context>

<process>
Выполни workflow из @$HOME_DIR/.claude/bpd/workflows/check.md от начала до конца.
</process>
