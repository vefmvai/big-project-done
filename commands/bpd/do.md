---
name: bpd:do
description: Выполнить следующий этап проекта (или конкретный по номеру)
argument-hint: "[номер этапа]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---
<objective>
Выполнить задачи этапа из PLAN.md. Создать RESULT.md с результатами.

Без аргумента — выполняет следующий спланированный этап.
С номером — выполняет конкретный (например, `/bpd:do 3`).

Для больших проектов использует субагент bpd-executor в свежем контексте.

После этой команды: `/bpd:check` для проверки.
</objective>

<execution_context>
@./.claude/bpd/workflows/do.md
@./.claude/bpd/templates/RESULT.md
</execution_context>

<context>
Номер этапа: $ARGUMENTS (необязательно)
</context>

<process>
Выполни workflow из @./.claude/bpd/workflows/do.md от начала до конца.
</process>
