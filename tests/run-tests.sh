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
has  "счёт этапов сошёлся" "принято: 2, всего этапов: 4, отменено: 1"

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
    "**Остановились на:** этап 02 в работе",
    "**Остановились на:** прогресс 50 %, этап 02 в работе"), "utf-8")
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
