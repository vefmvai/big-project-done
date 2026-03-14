---
name: bpd:update
description: Изменить дорожную карту — добавить, убрать, переставить, разбить этапы
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---
<objective>
Изменить дорожную карту проекта: добавить новый этап, убрать ненужный, переставить, изменить описание, разбить на части.

Автоматически пересчитывает нумерацию и обновляет STATE.md.
</objective>

<execution_context>
@./.claude/bpd/workflows/update.md
</execution_context>

<process>
Выполни workflow из @./.claude/bpd/workflows/update.md от начала до конца.
</process>
