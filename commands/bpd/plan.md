---
name: bpd:plan
description: Спланировать следующий этап проекта (или конкретный по номеру)
argument-hint: "[номер этапа]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
  - Task
---
<objective>
Создать детальный план этапа: задачи, ожидаемый результат, чеклист качества.

Без аргумента — планирует следующий неспланированный этап.
С номером — планирует конкретный этап (например, `/bpd:plan 5`).

После этой команды: `/bpd:do` для выполнения.
</objective>

<execution_context>
@$HOME_DIR/.claude/bpd/workflows/plan.md
@$HOME_DIR/.claude/bpd/templates/PLAN.md
</execution_context>

<context>
Номер этапа: $ARGUMENTS (необязательно — если не указан, берётся следующий)
</context>

<process>
Выполни workflow из @$HOME_DIR/.claude/bpd/workflows/plan.md от начала до конца.
</process>
