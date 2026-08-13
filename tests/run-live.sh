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
  echo "── /bpd:check 03.1 ──"
  P="$(project ch)"
  # Ничего не стираем: этап 04 выполнен и не проверен по-настоящему.
  # Раньше тест удалял чужой CHECK.md, и история в STATE.md оказывалась
  # впереди работы — проверщик это законно замечал.
  live "$P" "/bpd:check 03.1"
  F="$P/.bpd/stages/03.1-svodka/CHECK.md"
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

# ── 7. /bpd:start с нуля ───────────────────────────────────────────────────
# Первая команда, которую видит человек. До сих пор живым прогоном не
# проверялась вовсе — сверялись только команды, работающие на готовой папке.
if run_this start; then
  echo
  echo "── /bpd:start на пустой папке ──"
  P="$STAND/st0"; mkdir -p "$P"
  live "$P" "/bpd:start Проект: сборник из трёх коротких заметок о работе над долгими проектами, для себя. Результат: три файла с текстом и оглавление к ним. Ограничения: русский язык, сплошной текст без списков. Масштаб быстрый, режим автоматический, субагенты не нужны. Подтверждения не спрашивай: считай, что я на всё согласен, и доводи дело до конца."
  if [ -d "$P/.bpd" ]; then
    ok "папка .bpd/ создана"
    for f in PROJECT.md ROADMAP.md STATE.md config.json; do
      if [ -f "$P/.bpd/$f" ]; then ok "создан $f"; else bad "нет $f"; fi
    done
    STAGES=0
    for d in "$P"/.bpd/stages/*; do [ -d "$d" ] && STAGES=$((STAGES+1)); done
    if [ "$STAGES" -ge 1 ]; then ok "папок этапов: $STAGES"; else bad "папок этапов нет"; fi
    # Имя папки — две цифры с ведущим нулём и латиница (rules § 2).
    KRIVYE=""
    for d in "$P"/.bpd/stages/*; do
      [ -d "$d" ] || continue
      b="$(basename "$d")"
      echo "$b" | grep -qE '^[0-9]{2}-[a-z0-9]+(-[a-z0-9]+)*$' || KRIVYE="$KRIVYE $b"
    done
    if [ -z "$KRIVYE" ]; then ok "имена папок по формату NN-latinicej"; else bad "кривые имена:$KRIVYE"; fi
    if [ -f "$P/CLAUDE.md" ]; then ok "CLAUDE.md в корне создан"; else bad "CLAUDE.md в корне нет"; fi
  else
    bad "папка .bpd/ не создана — команда не довела дело до конца"
    note "$(echo "$OUT" | tail -3)"
  fi
  validate "$P" "после /bpd:start"
fi

# ── 8. Режим свежего контекста: планировщик-субагент ────────────────────────
# Здесь жил самый злой баг августа: субагенту обещали, что шаблон «уже
# загружен», и он выдумывал формат сам. Проверяем, что план приходит по шаблону.
if run_this subagents; then
  echo
  echo "── /bpd:plan 07 через субагента (use_subagents: true) ──"
  P="$(project sub)"
  rm -f "$P/.bpd/stages/07-final/PLAN.md"
  python3 - "$P" <<'PYEOF'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".bpd/config.json"
d = json.loads(p.read_text("utf-8"))
d["scale"] = "large"; d["use_subagents"] = True; d["mode"] = "automatic"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", "utf-8")
PYEOF
  live "$P" "/bpd:plan 07"
  F="$P/.bpd/stages/07-final/PLAN.md"
  if [ -f "$F" ]; then
    ok "субагент создал PLAN.md"
    MISS=""
    for h in "## Цель" "## Контекст" "## Задачи" "## Что нужно для начала" "## Ожидаемый результат" "## Чеклист качества"; do
      grep -qF "${h}" "$F" || MISS="$MISS ${h}"
    done
    if [ -z "$MISS" ]; then
      ok "план совпадает с шаблоном пункт в пункт — Б1 не вернулся"
    else
      bad "ВОЗВРАТ Б1: субагент выдумал формат, нет разделов:$MISS"
    fi
    if awk '/^## /{s=$0} /^[[:space:]]*[-*][[:space:]]*\[[ xX]\]/{if (s !~ /Задачи/) print}' "$F" | grep -q .; then
      bad "ВОЗВРАТ Б14: бокс вне раздела «Задачи»"
    else
      ok "галочек вне раздела «Задачи» нет"
    fi
  else
    bad "субагент не создал PLAN.md"
    note "$(echo "$OUT" | tail -3)"
  fi
  validate "$P" "после плана через субагента"
fi

# ── 9. Флажки по ролям: проверка свежая, планирование в текущем чате ───────
# Новая форма записи use_subagents (rules.md § 7). Проверяем, что команды
# на ней работают: план — в текущем чате, проверка — своим ходом до конца.
#
# ЧЕСТНО ПРО ГРАНИЦУ. Прогон НЕ ВИДИТ, кто именно проверял: `claude -p`
# отдаёт только последний ответ, запуск субагента в нём не отличить от работы
# в основном контексте. Здесь проверяется, что новая форма не ломает команды,
# а не то, что проверщик был отдельным. Считать это доказательством
# независимости нельзя.
if run_this roli; then
  echo
  echo "── use_subagents по ролям: plan в чате, check свежим взглядом ──"
  P="$(project roli)"
  rm -f "$P/.bpd/stages/07-final/PLAN.md"
  python3 - "$P" <<'PYEOF'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".bpd/config.json"
d = json.loads(p.read_text("utf-8"))
d["use_subagents"] = {"plan": False, "do": False, "check": True}
d["mode"] = "automatic"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", "utf-8")
PYEOF
  live "$P" "/bpd:plan 07"
  if [ -f "$P/.bpd/stages/07-final/PLAN.md" ]; then
    ok "план создан при plan: false"
  else
    bad "план не создан — новая форма записи сломала /bpd:plan"
    note "$(echo "$OUT" | tail -3)"
  fi
  live "$P" "/bpd:check 03.1"
  F="$P/.bpd/stages/03.1-svodka/CHECK.md"
  if [ -f "$F" ]; then
    ok "CHECK.md создан при check: true"
    V="$(awk '/^## Итог/{f=1;next} /^## /{f=0} f' "$F" | grep -vE '^[[:space:]]*$|^>' | head -1 | tr -d '*_ ')"
    case "$V" in
      Принято|Доработать) ok "вердикт ровно одним словом: $V" ;;
      *) bad "вердикт третьим словом: «${V}» — этап останется без статуса" ;;
    esac
  else
    bad "CHECK.md не создан — новая форма записи сломала /bpd:check"
    note "$(echo "$OUT" | tail -3)"
  fi
  validate "$P" "после работы на флажках по ролям"
fi

# ── 10. Полный круг: plan → do → check на одном этапе ──────────────────────
# Отдельные команды уже проверены. Здесь важно другое: доходит ли этап от
# «не начат» до «принят» подряд, и растёт ли прогресс.
if run_this krug; then
  echo
  echo "── Полный круг plan → do → check на этапе 07 ──"
  P="$(project krug)"
  rm -f "$P/.bpd/stages/07-final/PLAN.md"
  live "$P" "/bpd:plan 07"
  live "$P" "/bpd:do 07"
  live "$P" "/bpd:check 07"
  D="$P/.bpd/stages/07-final"
  for f in PLAN.md RESULT.md CHECK.md; do
    if [ -f "$D/$f" ]; then ok "круг дошёл до $f"; else bad "круг не дошёл до $f"; fi
  done
  if [ -f "$D/CHECK.md" ]; then
    V="$(awk '/^## Итог/{f=1;next} /^## /{f=0} f' "$D/CHECK.md" | grep -vE '^[[:space:]]*$|^>' | head -1 | tr -d '*_ ')"
    case "$V" in
      Принято|Доработать) ok "вердикт круга — одно слово: $V" ;;
      *) bad "вердикт круга третьим словом: «${V}»" ;;
    esac
  fi
  live "$P" "/bpd:status"
  want "прогресс вырос до 60 %" "60"
  validate "$P" "после полного круга"
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
