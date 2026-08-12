#!/usr/bin/env bash
# Тесты валидатора BPD.
#
# Чистая фикстура обязана давать код 0 и молчать: сторож, который кричит
# на здоровый проект, читать перестают.
# Ломаная обязана давать код 1, и каждая подсаженная поломка обязана быть
# названа поимённо — по номеру этапа, а не по заголовку раздела. Иначе один
# класс ошибок маскирует другой, и тест зелёный при неработающей проверке.
#
# Имена переменных латиницей: родной bash macOS — 3.2, русских имён он
# не понимает вовсе.
#
# Запуск: bash tests/run-tests.sh   (из любой папки)
# Код 0 = все проверки прошли.

set -u
cd "$(dirname "$0")/.." || { echo "не войти в корень плагина"; exit 2; }
PLUGIN="$(pwd)"
VALIDATE="$PLUGIN/bin/bpd-validate"
PY_VALIDATE="$PLUGIN/scripts/validate.py"
CLEAN="$PLUGIN/tests/fixtures/clean"
BROKEN="$PLUGIN/tests/fixtures/broken"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

OUT=""
CODE=0
run() { OUT="$("$VALIDATE" "$@" 2>&1)"; CODE=$?; }

# has <описание> <кусок текста> — ждём его в последнем выводе
has() {
  if echo "$OUT" | grep -qF -- "$2"; then ok "$1"; else bad "$1 — в выводе нет «$2»"; fi
}
hasnt() {
  if echo "$OUT" | grep -qF -- "$2"; then bad "$1 — в выводе НЕ должно быть «$2»"; else ok "$1"; fi
}

STAND="$(mktemp -d)"
trap 'rm -rf "$STAND"' EXIT

echo "── Чистая фикстура: код 0, ни ошибок, ни предупреждений ──"
run "$CLEAN"
if [ "$CODE" -eq 0 ]; then ok "код выхода 0"; else bad "код выхода $CODE (ждали 0)"; fi
has  "ошибок и предупреждений ноль" "предупреждений: 0, ошибок: 0"
hasnt "ни одного ❌ на здоровом проекте" "❌"
hasnt "ни одного ⚠️ на здоровом проекте" "⚠️"
has  "вердикт честный, а не «проект в порядке»" "заявленное непротиворечиво"
has  "сказано, что содержание не проверялось" "форму, а не содержание"
has  "счёт этапов сошёлся" "принято: 2, всего этапов: 5, отменено: 1"

echo
echo "── Ломаная фикстура: код 1 и каждая поломка названа ──"
run "$BROKEN"
if [ "$CODE" -eq 1 ]; then ok "код выхода 1"; else bad "код выхода $CODE (ждали 1)"; fi

has "1  две папки на один номер"        "этап 13: 13-a, 13-b"
has "2  бокс в чеклисте качества"       "01-galochki/PLAN.md"
has "3  вердикт третьим словом"         "этап 02: в разделе «## Итог» стоит"
has "4  RESULT.md раньше времени"       "этап 03: закрыто 1 из 3"
has "5  заявлен несуществующий файл"    "этап 04: заявлен netu-takogo-fajla.md"
has "6  RESULT.md без PLAN.md"          "этап 06: RESULT.md есть, а PLAN.md нет"
has "7а этап в карте без папки"         "этап 10 «Безпапки» есть в карте, а папки нет"
has "7б папка без этапа в карте"        "папка 11-lishnyaya есть, а этапа в карте нет"
has "8  имя папки без ведущего нуля"    "9-bezzero — нет ведущего нуля"
has "9  номер выдан дважды"             "номер 12 встречается 2 раза"
has "10 папка отменённого удалена"      "этап 14 «Пропавший» отменён"
has "11 колонка «Статус» в ROADMAP"     "ЗАВЕЛАСЬ КОЛОНКА «СТАТУС»"
has "12 процент в STATE.md"             "ЗАПИСАН ПРОГРЕСС ИЛИ СТАТУС"
has "13 следующий шаг не назван"        "НЕ НАЗВАН СЛЕДУЮЩИЙ ШАГ"
has "14 решение не доехало"             "РЕШЕНИЕ НЕ ДОЕХАЛО ДО PROJECT.md"
has "15 шаблонная рыба осталась"        "ШАБЛОННАЯ РЫБА"
has "16а русское значение в конфиге"    "mode = 'интерактивный'"
has "16б use_subagents строкой"         "use_subagents должен быть true/false"
has "16в дата не дата"                  "created = 'вчера'"
has "16г лишний ключ"                   "лишний ключ lishnij_klyuch"
has "17 путь до плагина в файле"        "ПУТЬ ДО ПЛАГИНА ЗАПИСАН"
has "18 счётчик не сходится"            "этап 08: в CHECK.md «Закрыто: 1 из 3»"
has "19 принят при незакрытом пункте"   "этап 09: «Принято», хотя"
has "20 решение осело в STATE.md"       "В STATE.md ЛЕЖИТ РЕШЕНИЕ"

echo
echo "── Предупреждение не роняет код выхода ──"
WARN="$STAND/warn"
cp -R "$CLEAN" "$WARN"
python3 - "$WARN" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".bpd/STATE.md"
p.write_text(p.read_text("utf-8").replace(
    "**Остановились на:** этап 04 выполнен",
    "**Остановились на:** прогресс 40 %, этап 04 выполнен"), "utf-8")
PY
run "$WARN"
if [ "$CODE" -eq 0 ]; then
  ok "предупреждение есть, код всё равно 0"
else
  bad "предупреждение уронило код до $CODE (ждали 0)"
fi
has "предупреждение при этом видно" "предупреждений: 1, ошибок: 0"

echo
echo "── Ошибка код выхода роняет ──"
ERR="$STAND/err"
cp -R "$CLEAN" "$ERR"
python3 - "$ERR" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]) / ".bpd/stages/01-osnova/CHECK.md"
p.write_text(p.read_text("utf-8").replace("\nПринято\n", "\nПочти принято\n"), "utf-8")
PY
run "$ERR"
if [ "$CODE" -eq 1 ]; then ok "одна ошибка → код 1"; else bad "одна ошибка → код $CODE"; fi

echo
echo "── Прогон не состоялся: код 2, а не 0 и не 1 ──"
run "$STAND/net-takoj-papki"
if [ "$CODE" -eq 2 ]; then ok "папки нет → код 2"; else bad "папки нет → код $CODE"; fi
has "и сказано, что это не «всё чисто»" "проверки не выполнялись"

NOBPD="$STAND/nobpd"; mkdir -p "$NOBPD"
run "$NOBPD"
if [ "$CODE" -eq 2 ]; then ok "не BPD-проект → код 2"; else bad "не BPD-проект → код $CODE"; fi
has "названа причина" "нет папки .bpd/"

NOMAP="$STAND/nomap"; mkdir -p "$NOMAP/.bpd"
run "$NOMAP"
if [ "$CODE" -eq 2 ]; then ok "нет карты → код 2"; else bad "нет карты → код $CODE"; fi

BADJSON="$STAND/badjson"
cp -R "$CLEAN" "$BADJSON"
printf '{ это не json' > "$BADJSON/.bpd/config.json"
run "$BADJSON"
if [ "$CODE" -eq 2 ]; then ok "конфиг не разбирается → код 2"; else bad "конфиг не разбирается → код $CODE"; fi

echo
echo "── Валидатор упал: тоже код 2, и вслух ──"
BROKEN_PY="$STAND/broken-validate.py"
sed 's/^def main() -> int:/def main() -> int:\n    raise RuntimeError("сбой изнутри валидатора")/' \
  "$PY_VALIDATE" > "$BROKEN_PY"
OUT="$(python3 "$BROKEN_PY" "$CLEAN" 2>&1)"; CODE=$?
if [ "$CODE" -eq 2 ]; then ok "падение → код 2, а не 1"; else bad "падение → код $CODE (ждали 2)"; fi
has "сказано, что чинить надо валидатор" "чинить надо валидатор, а не проект"

echo
echo "── Нет python3: обёртка обязана сказать это словами ──"
# Стенд честный: bash на месте, python3 нет. Пустой PATH не годился бы —
# без него не находится даже сам bash из строки #!/usr/bin/env bash,
# и тест мерил бы «нет оболочки» вместо «нет питона».
FAKEBIN="$STAND/bin"; mkdir -p "$FAKEBIN"
for tool in bash readlink; do
  src="$(command -v "$tool" 2>/dev/null)"
  [ -n "$src" ] && ln -sf "$src" "$FAKEBIN/$tool"
done
OUT="$(PATH="$FAKEBIN" "$VALIDATE" "$CLEAN" 2>&1)"; CODE=$?
if [ "$CODE" -eq 2 ]; then ok "нет python3 → код 2, а не 127"; else bad "нет python3 → код $CODE"; fi
has "названа причина и способ починки" "не найден python3"

echo
echo "── Хук автопрогона после записи ──"

# hook_say <папка проекта> <инструмент> <записанный файл>
# Печатает то, что хук положил в контекст (пусто = хук промолчал).
hook_say() {
  printf '{"tool_name":"%s","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$2" "$3" "$1" \
  | CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$1" \
    python3 "$PLUGIN/hooks/validate-on-write.py" 2>&1 \
  | python3 -c 'import json,sys
сырое = sys.stdin.read().strip()
if not сырое:
    sys.exit(0)
try:
    print(json.loads(сырое)["hookSpecificOutput"]["additionalContext"])
except Exception as беда:
    print("НЕ РАЗОБРАЛИ ОТВЕТ ХУКА:", беда, сырое[:200])'
}

# Ворота проверяем на ЗАВЕДОМО СЛОМАННОМ проекте: если проверять на здоровом,
# молчание хука ничего не докажет — он и так молчал бы.
NOGATE="$STAND/nogate"
cp -R "$BROKEN" "$NOGATE"
mv "$NOGATE/.bpd" "$NOGATE/bpd-otklyuchena"
SAY="$(hook_say "$NOGATE" Write "$NOGATE/bpd-otklyuchena/ROADMAP.md")"
if [ -z "$SAY" ]; then
  ok "без папки .bpd/ хук молчит даже на сломанном проекте"
else
  bad "без .bpd/ хук всё равно заговорил: $SAY"
fi

SAY="$(hook_say "$CLEAN" Write "$CLEAN/.bpd/ROADMAP.md")"
if [ -z "$SAY" ]; then ok "на здоровом проекте хук молчит"; else bad "хук шумит на здоровом: $SAY"; fi

SAY="$(hook_say "$BROKEN" Read "$BROKEN/.bpd/ROADMAP.md")"
if [ -z "$SAY" ]; then ok "на читающий инструмент хук не реагирует"; else bad "хук сработал на Read"; fi

SAY="$(hook_say "$BROKEN" Write "$BROKEN/razdel-1.md")"
if [ -z "$SAY" ]; then ok "на запись вне .bpd/ хук не реагирует"; else bad "хук сработал вне .bpd/"; fi

SAY="$(hook_say "$BROKEN" Write "$BROKEN/.bpd/ROADMAP.md")"
case "$SAY" in
  *"нашёл проблемы"*) ok "на сломанном проекте хук называет проблемы (код 1)" ;;
  *) bad "хук смолчал на сломанном проекте либо ответил не тем: $SAY" ;;
esac
case "$SAY" in
  *"этап 13: 13-a, 13-b"*) ok "в контекст попал сам отчёт валидатора" ;;
  *) bad "отчёт валидатора в контекст не попал" ;;
esac

# Валидатора нет на месте — это «не состоялось», а не «чисто».
NOVAL="$STAND/noval"; mkdir -p "$NOVAL/bin"
SAY="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"cwd":"%s"}' \
        "$BROKEN/.bpd/ROADMAP.md" "$BROKEN" \
      | CLAUDE_PLUGIN_ROOT="$NOVAL" CLAUDE_PROJECT_DIR="$BROKEN" \
        python3 "$PLUGIN/hooks/validate-on-write.py" 2>&1)"
case "$SAY" in
  *"не найден"*|*"не выполнена"*) ok "валидатора нет → хук говорит, а не молчит" ;;
  *) bad "валидатора нет, а хук смолчал: $SAY" ;;
esac

# Собственная поломка хука обязана быть названа вслух, код при этом 0.
BROKEN_HOOK="$STAND/broken-hook.py"
sed 's/^def main() -> None:/def main() -> None:\n    raise RuntimeError("сбой изнутри хука")/' \
  "$PLUGIN/hooks/validate-on-write.py" > "$BROKEN_HOOK"
cp "$PLUGIN/hooks/_common.py" "$STAND/_common.py"
SAY="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"cwd":"%s"}' \
        "$CLEAN/.bpd/ROADMAP.md" "$CLEAN" \
      | CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$CLEAN" \
        python3 "$BROKEN_HOOK" 2>&1)"; CODE=$?
if [ "$CODE" -eq 0 ]; then ok "сломанный хук не роняет работу инструмента (код 0)"; else bad "сломанный хук вернул $CODE"; fi
case "$SAY" in
  *"не отработал"*) ok "сломанный хук сознаётся вслух" ;;
  *) bad "сломанный хук промолчал: $SAY" ;;
esac

echo
echo "── Хук старта сессии ──"

start_say() {
  printf '{"cwd":"%s"}' "$1" \
  | CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$1" \
    python3 "$PLUGIN/hooks/session-start.py" 2>&1 \
  | python3 -c 'import json,sys
сырое = sys.stdin.read().strip()
if сырое:
    print(json.loads(сырое)["hookSpecificOutput"]["additionalContext"])'
}

SAY="$(start_say "$NOGATE")"
if [ -z "$SAY" ]; then ok "не BPD-проект → хук старта молчит"; else bad "хук старта заговорил зря: $SAY"; fi

SAY="$(start_say "$CLEAN")"
case "$SAY" in
  *"/bpd:check 04"*) ok "хук старта подаёт следующий шаг из STATE.md" ;;
  *) bad "следующий шаг не подан: $SAY" ;;
esac
case "$SAY" in
  *%*) bad "хук старта считает проценты — это дом /bpd:status" ;;
  *) ok "хук старта ничего не вычисляет сам" ;;
esac

echo
echo "── Текст не врёт о машине ──"
DECLARED="$(grep -m1 '^ПРОВЕРКИ = ' "$PY_VALIDATE" | tr -dc '0-9')"
ACTUAL="$(grep -c '^    # ── [0-9]' "$PY_VALIDATE")"
if [ "$DECLARED" = "$ACTUAL" ]; then
  ok "заявлено проверок $DECLARED, в коде столько же"
else
  bad "заявлено $DECLARED проверок, а в коде $ACTUAL"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Итого: $PASS ок, провалов нет."
  exit 0
fi
echo "Итого: $PASS ок, $FAIL провалов."
exit 1
