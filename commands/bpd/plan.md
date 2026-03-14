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
---
<objective>
Создать детальный план этапа: задачи, ожидаемый результат, чеклист качества.

Без аргумента — планирует следующий неспланированный этап.
С номером — планирует конкретный этап (например, `/bpd:plan 5`).

После этой команды: `/bpd:do` для выполнения.
</objective>

<execution_context>
@./.claude/bpd/workflows/plan.md
@./.claude/bpd/templates/PLAN.md
</execution_context>

<context>
Номер этапа: $ARGUMENTS (необязательно — если не указан, берётся следующий)
</context>

<process>
Выполни workflow из @./.claude/bpd/workflows/plan.md от начала до конца.
</process>
