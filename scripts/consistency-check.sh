#!/bin/bash
# consistency-check.sh - Проверка консистентности данных между файлами
# Запускается раз в неделю (крон). Не использует LLM, 0 токенов.
# Выводит противоречия для ручной проверки.
set -uo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/agents/main/agent}"
ISSUES=()

check_exact() {
  local label="$1"
  local pattern="$2"
  shift 2
  local files=("$@")
  local found_in=()
  local values=()

  for f in "${files[@]}"; do
    if [ -f "$WORKSPACE/$f" ]; then
      local match=$(grep -iP "$pattern" "$WORKSPACE/$f" 2>/dev/null | head -1)
      if [ -n "$match" ]; then
        found_in+=("$f")
        values+=("$(echo "$match" | sed 's/^[[:space:]]*//')")
      fi
    fi
  done

  if [ ${#found_in[@]} -gt 1 ]; then
    local unique=$(printf '%s\n' "${values[@]}" | sort -u | wc -l)
    if [ "$unique" -gt 1 ]; then
      ISSUES+=("⚠️ $label - разные значения:")
      for i in "${!found_in[@]}"; do
        ISSUES+=("   ${found_in[$i]}: ${values[$i]}")
      done
    fi
  fi
}

echo "🔍 Проверка консистентности данных..."
echo "Дата: $(date '+%Y-%m-%d %H:%M')"
echo "Workspace: $WORKSPACE"
echo ""

# === Примеры проверок (настрой под свои данные) ===

# Пример: проверка timezone
check_exact "Timezone" 'timezone|GMT\+|UTC\+' \
  "USER.md" "MEMORY.md"

# Пример: проверка основной модели
check_exact "Основная модель" 'model.*claude|model.*gpt|model.*gemini' \
  "MEMORY.md" "AGENTS.md"

# === Проверка MEMORY.md размера ===
MEM_SIZE=$(wc -c < "$WORKSPACE/MEMORY.md" 2>/dev/null || echo 0)
if [ "$MEM_SIZE" -gt 3000 ]; then
  ISSUES+=("🔴 MEMORY.md = ${MEM_SIZE} символов (рекомендуется < 3000)")
fi

# === Проверка дубликатов между bootstrap файлами ===
DUPES=$(cat "$WORKSPACE/AGENTS.md" "$WORKSPACE/TOOLS.md" "$WORKSPACE/IDENTITY.md" 2>/dev/null | \
  awk 'length > 30' | sort | uniq -d | grep -v "^$\|^#\|^-\|^\*\|^|\|^\`\`\`" | head -5)
if [ -n "$DUPES" ]; then
  ISSUES+=("📋 Дубликаты между bootstrap файлами:")
  while IFS= read -r line; do
    ISSUES+=("   $line")
  done <<< "$DUPES"
fi

# === Результат ===
echo ""
if [ "${#ISSUES[@]}" -eq 0 ]; then
  echo "✅ ALL_CONSISTENT - противоречий не найдено"
else
  echo "⚠️ Найдено ${#ISSUES[@]} потенциальных проблем:"
  echo ""
  for issue in "${ISSUES[@]}"; do
    echo "$issue"
  done
fi

echo ""
echo "💡 Добавь свои проверки: отредактируй секцию 'Примеры проверок' в скрипте."
echo "   Формат: check_exact \"Название\" 'regex-паттерн' \"файл1.md\" \"файл2.md\""
