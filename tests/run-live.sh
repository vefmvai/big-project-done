#!/usr/bin/env bash
# Живые прогоны: тест сам запускает Claude без окна и гоняет команды BPD.
#
# Самое дорогое и самое честное из всего набора. Линтер и валидатор проверяют
# ФАЙЛЫ; здесь проверяется ПОВЕДЕНИЕ — что команда делает то, что обещает.
# Три из пятнадцати багов августа нашёл только такой прогон, и они были злее
# тех двенадцати, что нашёл разбор глазами.
#
# ЧЕСТНО ПРО ЦЕНУ. Каждый сценарий — отдельный запуск Claude: это минуты
# и потраченные токены. Полный набор — «запустил и пошёл пить чай».
#
# ЧЕСТНО ПРО ЧИСТОТУ. Прогоны идут под профилем хозяина машины: пустой профиль
# не может войти в Claude, это проверено. Поэтому глобальные правила и прочие
# плагины в прогоне участвуют. Что изолировано: папка проекта одноразовая,
# установленная копия BPD отключена, список инструментов узкий.
#
# Запуск:  bash tests/run-live.sh            — все сценарии
#          bash tests/run-live.sh status     — только один, по имени

set -u
cd "$(dirname "$0")/.." || { echo "не войти в корень плагина"; exit 2; }
PLUGIN="$(pwd)"
CLEAN=""  # задаётся снимком ниже
ONLY="${1:-}"

PASS=0
FAIL=0
SKIP=0
ok()   { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
note() { echo "     $1"; }

command -v claude >/dev/null 2>&1 || {
  echo "ОШИБКА: не найден claude — живые прогоны невозможны." >&2
  echo "    Это НЕ «команды работают»: ни один сценарий не выполнялся." >&2
  exit 2
}

STAND="$(mktemp -d)"
# KEEP=1 — оставить стенд на диске, чтобы разобрать, что вышло.
if [ -z "${KEEP:-}" ]; then trap 'rm -rf "$STAND"' EXIT; else echo "   Стенд сохранён: $STAND"; fi

# Прогон идёт по СНИМКУ плагина, а не по живой папке. Иначе правка репозитория
# посреди прогона меняет то, что прогон измеряет, и результат ничего не значит.
# (Отдельно помнить: править сам этот скрипт во время его работы нельзя —
#  bash дочитывает файл по ходу и сбивается на сдвиге строк. Проверено собой.)
SNAPSHOT="$STAND/plugin"
mkdir -p "$SNAPSHOT"
(cd "$PLUGIN" && tar --exclude=.git -cf - .) | (cd "$SNAPSHOT" && tar -xf -)
PLUGIN_UNDER_TEST="$SNAPSHOT"
CLEAN="$SNAPSHOT/tests/fixtures/clean"

# Установленная копия BPD отключается, иначе прогон измерит не тот код.
# Проверено: с этой настройкой /bpd:* исчезает, если не подсунуть --plugin-dir.
SETTINGS="$STAND/settings.json"
cat > "$SETTINGS" <<'EOF'
{
  "enabledPlugins": { "bpd@vefmvai": false },
  "permissions": {
    "allow": ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task"],
    "deny": ["WebFetch", "WebSearch"]
  }
}
EOF

OUT=""
# live <папка проекта> <промпт> — запускает Claude в этой папке
live() {
  local dir="$1" prompt="$2"
  OUT="$(cd "$dir" && claude -p "$prompt" \
      --plugin-dir "$PLUGIN_UNDER_TEST" \
      --settings "$SETTINGS" \
      --permission-mode acceptEdits \
      < /dev/null 2>&1)"
  # Код возврата claude намеренно не проверяем: судим по тому, что осталось
  # на диске. «Отработал без ошибки» и «сделал что обещал» — разные вещи.
}

# проект <имя> — одноразовая копия чистой фикстуры
project() {
  local dir="$STAND/$1"
  cp -R "$CLEAN" "$dir"
  printf '%s' "$dir"
}

# validate <папка> — валидатор обязан быть доволен после работы команды
validate() {
  local dir="$1" desc="$2" out code
  out="$("$PLUGIN_UNDER_TEST/bin/bpd-validate" "$dir" 2>&1)"; code=$?
  if [ "$code" -eq 0 ]; then
    ok "$desc — валидатор доволен"
  else
    bad "$desc — валидатор недоволен (код $code)"
    echo "$out" | grep -E "^❌|^ *•" | head -8 | sed 's/^/       /'
  fi
}

want() { # want <описание> <кусок>
  if echo "$OUT" | grep -qF -- "$2"; then ok "$1"; else bad "$1 — в ответе нет «$2»"; fi
}

run_this() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

echo "══ Живые прогоны BPD ══"
echo "   Плагин: $PLUGIN"
echo "   Снимок: $SNAPSHOT"
echo "   Стенд:  $STAND"
echo

# ── 0. Пре-полёт: второй копии BPD быть не должно ──────────────────────────
echo "── Пре-полёт ──"
LEGACY=""
for p in "$HOME/.claude/commands/bpd" "$HOME/.claude/bpd" "$HOME/.claude/skills/bpd"; do
  [ -e "$p" ] && LEGACY="$LEGACY $p"
done
ls "$HOME"/.claude/agents/bpd-*.md >/dev/null 2>&1 && LEGACY="$LEGACY ~/.claude/agents/bpd-*.md"
if [ -z "$LEGACY" ]; then
  ok "старой установки 1.x на диске нет"
else
  bad "найдена вторая копия BPD:$LEGACY"
  note "Прогон измерит её, а не эту папку. Убрать: bash scripts/remove-legacy-install.sh"
fi

live "$STAND" "/bpd:help"
if echo "$OUT" | grep -q "Unknown command"; then
  bad "команды /bpd:* не загрузились из --plugin-dir"
  note "$OUT"
  echo "Дальше идти незачем."; exit 1
else
  ok "команды загружаются из проверяемой папки"
fi

# ── 1. /bpd:help ───────────────────────────────────────────────────────────
if run_this help; then
  echo
  echo "── /bpd:help ──"
  MISSING=""
  # «do» в кавычках: без них shellcheck читает его как ключевое слово цикла.
  for c in start plan 'do' check status update help; do
    echo "$OUT" | grep -q "/bpd:$c" || MISSING="$MISSING /bpd:$c"
  done
  if [ -z "$MISSING" ]; then ok "справка называет все семь команд"; else bad "в справке нет:$MISSING"; fi
fi

# ── 2. /bpd:status ─────────────────────────────────────────────────────────
if run_this status; then
  echo
  echo "── /bpd:status на готовой фикстуре ──"
  P="$(project st)"
  live "$P" "/bpd:status"
  want "прогресс посчитан как 40 %" "40"
  want "видно принятый этап" "Принят"
  want "видно отменённый этап" "Отменён"
  if echo "$OUT" | grep -q "◐"; then ok "видно этап в работе"; else bad "этап в работе не показан"; fi
  if echo "$OUT" | grep -qE "01.*02.*07.*03.*04"; then
    ok "этапы идут в порядке карты, а не по возрастанию номера"
  else
    note "порядок этапов проверить глазами (вывод свободной формы)"
  fi
  validate "$P" "после /bpd:status ничего не сломалось"
fi

# ── 3. /bpd:plan ───────────────────────────────────────────────────────────
if run_this plan; then
  echo
  echo "── /bpd:plan 07 ──"
  P="$(project pl)"
  rm -f "$P/.bpd/stages/07-final/PLAN.md"
  live "$P" "/bpd:plan 07"
  F="$P/.bpd/stages/07-final/PLAN.md"
  if [ -f "$F" ]; then
    ok "PLAN.md создан"
    for h in "## Цель" "## Задачи" "## Чеклист качества" "## Ожидаемый результат"; do
      if grep -qF "$h" "$F"; then ok "в плане есть раздел «${h}»"; else bad "в плане нет раздела «${h}»"; fi
    done
    N="$(grep -cE '^[[:space:]]*[-*][[:space:]]*\[[ xX]\]' "$F")"
    [ -n "$N" ] || N=0
    if [ "$N" -ge 3 ] && [ "$N" -le 10 ]; then
      ok "задач $N — в пределах 3–10"
    else
      bad "задач $N, а правило требует 3–10"
    fi
    # Возврат бага Б14: боксы только в разделе «Задачи».
    if awk '/^## /{s=$0} /^[[:space:]]*[-*][[:space:]]*\[[ xX]\]/{if (s !~ /Задачи/) print}' "$F" | grep -q .; then
      bad "ВОЗВРАТ Б14: бокс вне раздела «Задачи»"
    else
      ok "галочек вне раздела «Задачи» нет"
    fi
  else
    bad "PLAN.md не создан"
    note "$(echo "$OUT" | tail -3)"
  fi
  validate "$P" "после /bpd:plan"
fi

# ── 4. /bpd:do ─────────────────────────────────────────────────────────────
if run_this 'do'; then
  echo
  echo "── /bpd:do 02 ──"
  P="$(project 'do')"
  live "$P" "/bpd:do 02"
  F="$P/.bpd/stages/02-sbor"
  # grep -c при нуле совпадений печатает «0» И возвращает единицу, поэтому
  # запасной «|| echo 0» дописывал второй ноль и ломал сравнение чисел.
  # \s в BSD grep тоже не гарантирован — берём POSIX-класс.
  OPEN="$(grep -cE '^[[:space:]]*[-*][[:space:]]*\[ \]' "$F/PLAN.md" 2>/dev/null)"
  [ -n "$OPEN" ] || OPEN=0
  if [ -f "$F/RESULT.md" ]; then
    ok "RESULT.md создан"
    if [ "$OPEN" -eq 0 ]; then
      ok "RESULT.md появился только после закрытия всех задач"
    else
      bad "ВОЗВРАТ Б4: RESULT.md есть, а незакрытых задач $OPEN"
    fi
    for h in "## Что сделано" "## Созданные и изменённые файлы"; do
      if grep -qF "$h" "$F/RESULT.md"; then ok "в отчёте есть «${h}»"; else bad "в отчёте нет «${h}»"; fi
    done
  elif [ "$OPEN" -eq 0 ]; then
    bad "все задачи закрыты, а RESULT.md нет — работа встала на отчёте"
  else
    bad "RESULT.md не создан, незакрытых задач $OPEN"
    note "$(echo "$OUT" | tail -3)"
  fi
  validate "$P" "после /bpd:do"
fi

# ── 5. /bpd:check ──────────────────────────────────────────────────────────
if run_this check; then
  echo
  echo "── /bpd:check 04 ──"
  P="$(project ch)"
  # Ничего не стираем: этап 04 выполнен и не проверен по-настоящему.
  # Раньше тест удалял чужой CHECK.md, и история в STATE.md оказывалась
  # впереди работы — проверщик это законно замечал.
  live "$P" "/bpd:check 04"
  F="$P/.bpd/stages/04-svodka/CHECK.md"
  if [ -f "$F" ]; then
    ok "CHECK.md создан"
    for h in "## Задачи из плана" "## Заявленные файлы" "## Чеклист качества" "## Итог" "## Замечания"; do
      if grep -qF "$h" "$F"; then ok "в отчёте проверки есть «${h}»"; else bad "нет раздела «${h}»"; fi
    done
    V="$(awk '/^## Итог/{f=1;next} /^## /{f=0} f' "$F" | grep -vE '^\s*$|^>' | head -1 | tr -d '*_ ')"
    case "$V" in
      Принято|Доработать) ok "вердикт ровно одним словом: $V" ;;
      *) bad "вердикт третьим словом: «${V}» — этап останется без статуса" ;;
    esac
  else
    bad "CHECK.md не создан"
    note "$(echo "$OUT" | tail -3)"
  fi
  validate "$P" "после /bpd:check"
fi

# ── 6. /bpd:update ─────────────────────────────────────────────────────────
if run_this update; then
  echo
  echo "── /bpd:update: добавить этап ──"
  P="$(project up)"
  BEFORE="$(cd "$P/.bpd/stages" && ls | sort | tr '\n' ' ')"
  live "$P" "/bpd:update добавь новый этап «Вычитка» после этапа 03 — вычитать все разделы на опечатки"
  AFTER="$(cd "$P/.bpd/stages" && ls | sort | tr '\n' ' ')"
  # Старые папки обязаны остаться с теми же именами: номера вечные (rules § 6).
  KEPT=1
  for d in $BEFORE; do
    case " $AFTER " in *" $d "*) ;; *) KEPT=0; bad "папка $d переименована или исчезла" ;; esac
  done
  [ "$KEPT" -eq 1 ] && ok "ВОЗВРАТ Б5 не случился: старые папки не переименованы"
  NEW=""
  for d in "$P"/.bpd/stages/08-*; do [ -d "$d" ] && NEW="$d"; done
  if [ -n "$NEW" ]; then
    ok "новый этап получил номер 08 (максимальный 07 плюс один)"
  else
    bad "нового этапа с номером 08 нет; сейчас: $AFTER"
  fi
  validate "$P" "после /bpd:update"
fi

echo
echo "─────────────────────────────────────────"
if [ "$FAIL" -eq 0 ]; then
  echo "Итого: $PASS ок, провалов нет."
  [ "$SKIP" -gt 0 ] && echo "Пропущено сценариев: $SKIP"
  exit 0
fi
echo "Итого: $PASS ок, $FAIL провалов."
exit 1
