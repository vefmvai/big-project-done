#!/bin/bash

# BPD (Big Project Done) — установщик
# Устанавливает фреймворк ГЛОБАЛЬНО в ~/.claude/
# После установки команды /bpd:* доступны в любом проекте

set -e

# Определяем где лежит сам скрипт (папка с файлами BPD)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Целевая папка — глобальная конфигурация Claude Code
TARGET_DIR="$HOME/.claude"

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   BPD — Big Project Done v1.1.0"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Глобальная установка в: $TARGET_DIR/"
echo ""

# Создаём структуру папок
mkdir -p "$TARGET_DIR/commands/bpd"
mkdir -p "$TARGET_DIR/agents"
mkdir -p "$TARGET_DIR/bpd/workflows"
mkdir -p "$TARGET_DIR/bpd/templates"

# Копируем команды (с подстановкой путей)
for file in "$SCRIPT_DIR/commands/bpd/"*.md; do
  sed "s|\\\$HOME_DIR|$HOME|g" "$file" > "$TARGET_DIR/commands/bpd/$(basename "$file")"
done
echo "  ✓ Команды установлены (7 файлов)"

# Копируем агентов
cp "$SCRIPT_DIR/agents/"*.md "$TARGET_DIR/agents/"
echo "  ✓ Агенты установлены (3 файла)"

# Копируем workflows
cp "$SCRIPT_DIR/workflows/"*.md "$TARGET_DIR/bpd/workflows/"
echo "  ✓ Workflows установлены (7 файлов)"

# Копируем шаблоны
cp "$SCRIPT_DIR/templates/"* "$TARGET_DIR/bpd/templates/"
echo "  ✓ Шаблоны установлены (8 файлов)"

echo ""
echo "  ✓ BPD установлен глобально!"
echo ""
echo "  Команды /bpd:* теперь доступны в любом проекте."
echo "  Откройте папку проекта и запустите /bpd:start"
echo ""
echo "  /bpd:help — справка по командам"
echo ""
