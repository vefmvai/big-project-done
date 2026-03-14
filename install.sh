#!/bin/bash

# BPD (Big Project Done) — установщик
# Копирует файлы фреймворка в .claude/ текущего проекта

set -e

# Определяем где лежит сам скрипт (папка с файлами BPD)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Целевая папка — текущая директория пользователя
TARGET_DIR="$(pwd)"

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   BPD — Big Project Done v1.0.0"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Установка в: $TARGET_DIR/.claude/"
echo ""

# Создаём структуру папок
mkdir -p "$TARGET_DIR/.claude/commands/bpd"
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/.claude/bpd/workflows"
mkdir -p "$TARGET_DIR/.claude/bpd/templates"

# Копируем команды
cp "$SCRIPT_DIR/commands/bpd/"*.md "$TARGET_DIR/.claude/commands/bpd/"
echo "  ✓ Команды установлены (7 файлов)"

# Копируем агентов
cp "$SCRIPT_DIR/agents/"*.md "$TARGET_DIR/.claude/agents/"
echo "  ✓ Агенты установлены (2 файла)"

# Копируем workflows
cp "$SCRIPT_DIR/workflows/"*.md "$TARGET_DIR/.claude/bpd/workflows/"
echo "  ✓ Workflows установлены (7 файлов)"

# Копируем шаблоны
cp "$SCRIPT_DIR/templates/"* "$TARGET_DIR/.claude/bpd/templates/"
echo "  ✓ Шаблоны установлены (7 файлов)"

echo ""
echo "  ✓ BPD установлен!"
echo ""
echo "  Запустите /bpd:start в Claude Code"
echo "  чтобы начать новый проект."
echo ""
echo "  /bpd:help — справка по командам"
echo ""
