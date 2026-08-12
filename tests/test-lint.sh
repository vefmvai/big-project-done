#!/usr/bin/env bash
# Проверка сторожа: каждая проверка линтера обязана поймать свою поломку.
#
# Зелёный линтер ничего не доказывает, пока не показано, что он умеет краснеть.
# Здесь берётся чистая копия плагина, в неё по одной подсаживается ровно одна
# поломка, и проверяется, что линтер называет именно её, а не «что-то».
#
# Имена переменных и функций — латиницей намеренно: родной bash macOS это
# версия 3.2, и русские имена он не понимает вовсе («unbound variable»).
# Тексты и комментарии при этом русские — их bash не разбирает.
#
# Запуск: bash tests/test-lint.sh   (из любой папки)
# Код 0 = все проверки сторожа сработали.

set -u
cd "$(dirname "$0")/.." || { echo "не войти в корень плагина"; exit 2; }
PLUGIN="$(pwd)"
LINTER="$PLUGIN/tests/lint-plugin.py"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

STAND="$(mktemp -d)"
trap 'rm -rf "$STAND"' EXIT
PRISTINE="$STAND/pristine"
WORK="$STAND/work"

# Эталон без .git: копировать историю в стенд незачем.
mkdir -p "$PRISTINE"
(cd "$PLUGIN" && tar --exclude=.git -cf - .) | (cd "$PRISTINE" && tar -xf -)

reset_copy() { rm -rf "$WORK"; cp -R "$PRISTINE" "$WORK"; }

# run_lint <папка> — печатает вывод, возвращает код линтера
OUT=""
CODE=0
run_lint() { OUT="$(python3 "$LINTER" "$1" 2>&1)"; CODE=$?; }

# break_it <описание> <ожидаемый кусок текста> <python-код правки>
# Правка выполняется в папке $WORK. Ожидаем код 1 и названную поломку.
break_it() {
  desc="$1"; want="$2"; patch="$3"
  reset_copy
  if ! (cd "$WORK" && python3 -c "$patch"); then
    bad "$desc — не удалось подсадить поломку (ошибка в самом тесте)"
    return
  fi
  run_lint "$WORK"
  if [ "$CODE" -ne 1 ]; then
    bad "$desc — код $CODE, а ждали 1"
    return
  fi
  if echo "$OUT" | grep -qF -- "$want"; then
    ok "$desc"
  else
    bad "$desc — код 1 верный, но в выводе нет «${want}»"
  fi
}

echo "── Чистая копия: линтер обязан молчать ──"
reset_copy
run_lint "$WORK"
if [ "$CODE" -eq 0 ]; then
  ok "код выхода 0 на здоровом плагине"
else
  bad "код выхода $CODE на здоровом плагине"
  echo "$OUT" | grep -E "^❌|^ОШИБКА" | head -5
fi

echo
echo "── Подсаженные поломки: каждая обязана быть названа ──"

break_it "П1 версия разошлась" "ВЕРСИИ РАЗОШЛИСЬ" '
import json, pathlib
p = pathlib.Path(".claude-plugin/plugin.json")
d = json.loads(p.read_text("utf-8")); d["version"] = "9.9.9"
p.write_text(json.dumps(d, ensure_ascii=False, indent=2), "utf-8")'

break_it "П2 вернулась фраза «уже загружен»" "ВОЗВРАТ БАГА Б1" '
import pathlib
p = pathlib.Path("skills/do/SKILL.md")
p.write_text(p.read_text("utf-8") + "\nШаблон уже загружен в контексте.\n", "utf-8")'

break_it "П3 из промпта пропал путь к правилам" "ПРОМПТ СУБАГЕНТА БЕЗ ПУТЕЙ" '
import pathlib
p = pathlib.Path("skills/do/SKILL.md")
p.write_text(p.read_text("utf-8").replace(
    "${CLAUDE_PLUGIN_ROOT}/references/rules.md", "правила"), "utf-8")'

break_it "П4 в конфиг вернулось русское значение" "ВОЗВРАТ БАГА Б3" '
import pathlib
p = pathlib.Path("templates/config.json")
p.write_text(p.read_text("utf-8").replace(
    chr(34) + "interactive" + chr(34), chr(34) + "интерактивный" + chr(34)), "utf-8")'

break_it "П4 лишний ключ в конфиге" "ВОЗВРАТ БАГА Б3" '
import json, pathlib
p = pathlib.Path("templates/config.json")
d = json.loads(p.read_text("utf-8")); d["lishnij"] = 1
p.write_text(json.dumps(d, ensure_ascii=False, indent=2), "utf-8")'

break_it "П5 формула прогресса завелась во втором месте" "ВОЗВРАТ БАГА Б2" '
import pathlib
p = pathlib.Path("README.md")
p.write_text(p.read_text("utf-8") +
    "\nпрогресс = завершённые этапы ÷ (все этапы − отменённые)\n", "utf-8")'

break_it "П6 бокс в чеклисте качества" "ВОЗВРАТ БАГА Б14" '
import pathlib
p = pathlib.Path("templates/PLAN.md")
p.write_text(p.read_text("utf-8").replace(
    "## Чеклист качества", "## Чеклист качества\n\n- [ ] чужая галочка", 1), "utf-8")'

break_it "П7 из README пропала строка статуса" "README РАЗОШЁЛСЯ С КАНОНОМ" '
import pathlib
p = pathlib.Path("README.md")
lines = [s for s in p.read_text("utf-8").split(chr(10)) if "⚠ На доработке" not in s]
p.write_text(chr(10).join(lines), "utf-8")'

break_it "П8 диапазоны масштабов разъехались" "ТАБЛИЦЫ МАСШТАБОВ РАЗОШЛИСЬ" '
import pathlib
p = pathlib.Path("references/commands.md")
p.write_text(p.read_text("utf-8").replace("| Быстрый | 1–4 |", "| Быстрый | 1–7 |"), "utf-8")'

break_it "П9 ссылка на несуществующий файл плагина" "ССЫЛКА В НИКУДА" '
import pathlib
p = pathlib.Path("skills/help/SKILL.md")
p.write_text(p.read_text("utf-8") +
    "\nСмотри ${CLAUDE_PLUGIN_ROOT}/references/vydumka.md\n", "utf-8")'

break_it "П10 имя навыка не совпало с папкой" "ШАПКИ СЛОМАНЫ" '
import pathlib
p = pathlib.Path("skills/status/SKILL.md")
p.write_text(p.read_text("utf-8").replace("name: status", "name: statuss", 1), "utf-8")'

break_it "П11 справка обещает несуществующую команду" "ВОЗВРАТ БАГА Б10" '
import pathlib
p = pathlib.Path("references/commands.md")
p.write_text(p.read_text("utf-8") + "\n| `/bpd:vydumka` | команда-призрак |\n", "utf-8")'

break_it "П12 из шаблона пропал искомый раздел" "В ШАБЛОНЕ НЕТ РАЗДЕЛА" '
import pathlib
p = pathlib.Path("templates/RESULT.md")
p.write_text(p.read_text("utf-8").replace("## Принятые решения", "## Решения", 1), "utf-8")'

break_it "П13 в раздел «Итог» вернулось пояснение" "РАЗДЕЛ «## Итог» ЗАСОРЁН" '
import pathlib
p = pathlib.Path("templates/CHECK.md")
p.write_text(p.read_text("utf-8").replace(
    "## Итог\n", "## Итог\n\n> Пишется «Принято» или «Доработать».\n", 1), "utf-8")'

break_it "П15 переменная без скобок перед русским" "ПЕРЕМЕННАЯ БЕЗ СКОБОК" '
import pathlib
p = pathlib.Path("tests/run-tests.sh")
примана = chr(36) + "PASS" + chr(187)
p.write_text(p.read_text("utf-8") + chr(10) + "echo " + chr(34) + примана + chr(34) + chr(10), "utf-8")'

break_it "П16 пустая папка в репозитории" "ПУСТАЯ ПАПКА" '
import pathlib
pathlib.Path("templates/pustaya-papka").mkdir()'

echo
echo "── Правило переписано дословно: предупреждение, но не ошибка ──"
reset_copy
python3 - "$WORK" <<'PY'
import pathlib, sys
work = pathlib.Path(sys.argv[1])
canon = [s for s in (work / "references/rules.md").read_text("utf-8").split("\n")
         if len(s.strip()) >= 60 and not s.strip().startswith(("|", "#", ">", "-", "`"))][0]
guide = work / "GUIDE.md"
guide.write_text(guide.read_text("utf-8") + "\n" + canon.strip() + "\n", "utf-8")
PY
run_lint "$WORK"
if [ "$CODE" -eq 0 ] && echo "$OUT" | grep -qF "ПРАВИЛА ПЕРЕПИСАНЫ"; then
  ok "П14 копию правила видно, но код выхода она не роняет"
else
  bad "П14 — код $CODE, ждали 0 с предупреждением «ПРАВИЛА ПЕРЕПИСАНЫ»"
fi

echo
echo "── Прогон не состоялся: обязан быть код 2, а не 0 и не 1 ──"
EMPTY="$STAND/empty"; mkdir -p "$EMPTY"
run_lint "$EMPTY"
if [ "$CODE" -eq 2 ] && echo "$OUT" | grep -qF "не похож на корень плагина"; then
  ok "не корень плагина → код 2, а не «всё чисто»"
else
  bad "не корень плагина → код $CODE (ждали 2)"
fi

reset_copy
rm -f "$WORK/templates/config.json"
run_lint "$WORK"
if [ "$CODE" -eq 2 ] && echo "$OUT" | grep -qF "проверять нечего"; then
  ok "пропал нужный файл → код 2, а не «ошибок нет»"
else
  bad "пропал нужный файл → код $CODE (ждали 2)"
fi

reset_copy
BROKEN="$STAND/broken-lint.py"
sed 's/^def main() -> int:/def main() -> int:\n    raise RuntimeError("сбой изнутри линтера")/' \
  "$LINTER" > "$BROKEN"
OUT="$(python3 "$BROKEN" "$WORK" 2>&1)"; CODE=$?
if [ "$CODE" -eq 2 ] && echo "$OUT" | grep -qF "Прогон НЕ СОСТОЯЛСЯ"; then
  ok "линтер упал → код 2 и текст вслух, а не тихое «чисто»"
else
  bad "линтер упал → код $CODE (ждали 2)"
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "Итого: $PASS ок, провалов нет. Сторож умеет краснеть."
  exit 0
fi
echo "Итого: $PASS ок, $FAIL провалов."
exit 1
