#!/bin/bash
#
# Убирает следы старой установки BPD 1.x из ~/.claude/
#
# BPD 1.x ставился скриптом install.sh, который раскидывал файлы по четырём
# папкам глобальной конфигурации Claude Code. BPD 2.0 — плагин: он живёт
# в своей папке и ставится через /plugin install.
#
# Пока старые файлы лежат на месте, у вас две копии команд /bpd:*, и какая
# сработает — вопрос везения. Этот скрипт убирает старую.
#
# ВАЖНО: рабочие папки проектов (.bpd/ внутри ваших проектов) скрипт
# не трогает вообще. Формат .bpd/ в версии 2.0 не менялся — старые проекты
# продолжают работать.

set -e

TARGET="$HOME/.claude"

LEGACY_PATHS=(
  "$TARGET/commands/bpd"
  "$TARGET/bpd"
  "$TARGET/agents/bpd-planner.md"
  "$TARGET/agents/bpd-executor.md"
  "$TARGET/agents/bpd-checker.md"
)

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   BPD — уборка старой установки 1.x"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

FOUND=0
for path in "${LEGACY_PATHS[@]}"; do
  if [ -e "$path" ]; then
    echo "  найдено: $path"
    FOUND=1
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "  Старой установки нет — убирать нечего."
  echo ""
  exit 0
fi

echo ""
printf "  Удалить перечисленное? [y/N] "
read -r ANSWER

case "$ANSWER" in
  [yY]|[yY][eE][sS]) ;;
  *)
    echo ""
    echo "  Отменено. Ничего не тронуто."
    echo ""
    exit 0
    ;;
esac

for path in "${LEGACY_PATHS[@]}"; do
  if [ -e "$path" ]; then
    rm -rf "$path"
    echo "  ✓ убрано: $path"
  fi
done

echo ""
echo "  Готово. Теперь поставьте плагин:"
echo ""
echo "    /plugin marketplace add vefmvai/claude-plugins"
echo "    /plugin install bpd@vefmvai"
echo ""
echo "  Ваши проекты с папкой .bpd/ продолжат работать как раньше."
echo ""
