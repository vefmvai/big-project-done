---
name: bpd:start
description: Начать новый проект — интервью, описание, дорожная карта. Используй когда пользователь хочет начать большой проект с нуля.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---
<objective>
Инициализация нового проекта через интервью с пользователем.

Создаёт в текущей директории:
- `CLAUDE.md` — инструкции для Claude Code
- `.bpd/PROJECT.md` — описание проекта
- `.bpd/ROADMAP.md` — дорожная карта
- `.bpd/STATE.md` — текущее состояние
- `.bpd/config.json` — настройки

Также сохраняет project memory для будущих сессий.

После этой команды: `/bpd:plan` для планирования первого этапа.
</objective>

<execution_context>
@$HOME_DIR/.claude/bpd/workflows/start.md
@$HOME_DIR/.claude/bpd/templates/PROJECT.md
@$HOME_DIR/.claude/bpd/templates/ROADMAP.md
@$HOME_DIR/.claude/bpd/templates/STATE.md
@$HOME_DIR/.claude/bpd/templates/CLAUDE.md
@$HOME_DIR/.claude/bpd/templates/config.json
</execution_context>

<process>
Выполни workflow из @$HOME_DIR/.claude/bpd/workflows/start.md от начала до конца.
Следуй всем шагам и проверкам.
</process>
