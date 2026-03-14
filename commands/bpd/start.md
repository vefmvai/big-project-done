---
name: bpd:start
description: Начать новый проект — интервью, описание, дорожная карта. Используй когда пользователь хочет начать большой проект с нуля.
allowed-tools:
  - Read
  - Write
  - Bash
  - AskUserQuestion
---
<objective>
Инициализация нового проекта через интервью с пользователем.

Создаёт:
- `.bpd/PROJECT.md` — описание проекта
- `.bpd/ROADMAP.md` — дорожная карта
- `.bpd/STATE.md` — текущее состояние
- `.bpd/config.json` — настройки

После этой команды: `/bpd:plan` для планирования первого этапа.
</objective>

<execution_context>
@./.claude/bpd/workflows/start.md
@./.claude/bpd/templates/PROJECT.md
@./.claude/bpd/templates/ROADMAP.md
@./.claude/bpd/templates/STATE.md
@./.claude/bpd/templates/config.json
</execution_context>

<process>
Выполни workflow из @./.claude/bpd/workflows/start.md от начала до конца.
Следуй всем шагам и проверкам.
</process>
