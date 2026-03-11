#!/bin/bash
# health-check.sh - Проверка здоровья системы памяти
# Не использует LLM, 0 токенов.
set -uo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/agents/main/agent}"
MEMORY_DIR="$WORKSPACE/memory"
OPENCLAW_DIR="$HOME/.openclaw"
GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
ERRORS=0

echo "🔍 Health Check: система памяти"
echo "Дата: $(date '+%Y-%m-%d %H:%M')"
echo "Workspace: $WORKSPACE"
echo ""

# 1. Критичные файлы
echo "=== Критичные файлы ==="
for f in MEMORY.md AGENTS.md IDENTITY.md; do
  if [ -f "$WORKSPACE/$f" ]; then
    echo "  ✅ $f"
  else
    echo "  ❌ $f - НЕ НАЙДЕН!"
    ERRORS=$((ERRORS+1))
  fi
done

# 2. Handoff
echo ""
echo "=== Handoff ==="
if [ -f "$MEMORY_DIR/handoff.md" ]; then
  AGE_SEC=$(( $(date +%s) - $(stat -f %m "$MEMORY_DIR/handoff.md" 2>/dev/null || stat -c %Y "$MEMORY_DIR/handoff.md" 2>/dev/null || echo 0) ))
  AGE_HOURS=$((AGE_SEC / 3600))
  if [ "$AGE_HOURS" -gt 24 ]; then
    echo "  ⚠️ handoff.md устарел (${AGE_HOURS}ч назад)"
  else
    echo "  ✅ handoff.md актуален (${AGE_HOURS}ч назад)"
  fi
else
  echo "  ❌ handoff.md - НЕ НАЙДЕН!"
  ERRORS=$((ERRORS+1))
fi

# 3. MEMORY.md размер
echo ""
echo "=== MEMORY.md ==="
if [ -f "$WORKSPACE/MEMORY.md" ]; then
  SIZE=$(wc -c < "$WORKSPACE/MEMORY.md")
  if [ "$SIZE" -gt 3000 ]; then
    echo "  ⚠️ MEMORY.md = ${SIZE} символов (рекомендуется < 3000)"
  else
    echo "  ✅ MEMORY.md = ${SIZE} символов"
  fi
fi

# 4. Структура памяти
echo ""
echo "=== Структура памяти ==="
for d in core decisions projects archive/daily; do
  if [ -d "$MEMORY_DIR/$d" ]; then
    COUNT=$(find "$MEMORY_DIR/$d" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    echo "  ✅ memory/$d/ ($COUNT файлов)"
  else
    echo "  ❌ memory/$d/ - НЕ НАЙДЕНА!"
    ERRORS=$((ERRORS+1))
  fi
done

# 5. Daily notes
echo ""
echo "=== Daily notes ==="
NOTES=$(find "$MEMORY_DIR" -maxdepth 1 -name "20??-*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "  📝 Активных daily notes: $NOTES"
OLD_NOTES=$(find "$MEMORY_DIR" -maxdepth 1 -name "20??-*.md" -mtime +14 2>/dev/null | wc -l | tr -d ' ')
if [ "$OLD_NOTES" -gt 0 ]; then
  echo "  ⚠️ Старше 14 дней: $OLD_NOTES (нужна архивация)"
fi

# 6. SQLite (если есть)
echo ""
echo "=== Векторная память ==="
SQLITE_DB="$OPENCLAW_DIR/memory/main.sqlite"
if [ -f "$SQLITE_DB" ]; then
  SIZE_MB=$(du -m "$SQLITE_DB" | cut -f1)
  WAL=$(sqlite3 "$SQLITE_DB" "PRAGMA journal_mode;" 2>/dev/null || echo "unknown")
  echo "  ✅ main.sqlite: ${SIZE_MB}MB, journal: $WAL"
  if [ "$WAL" != "wal" ]; then
    echo "  ⚠️ WAL mode отключён! Рекомендуется: sqlite3 $SQLITE_DB 'PRAGMA journal_mode=WAL;'"
    ERRORS=$((ERRORS+1))
  fi
else
  echo "  ℹ️ Векторная память не настроена (нет main.sqlite)"
fi

# 7. Gateway
echo ""
echo "=== Gateway ==="
if curl -sf "http://127.0.0.1:${GATEWAY_PORT}/health" > /dev/null 2>&1; then
  echo "  ✅ Gateway работает"
else
  echo "  ❌ Gateway не отвечает!"
  ERRORS=$((ERRORS+1))
fi

# Итог
echo ""
echo "================================"
if [ "$ERRORS" -eq 0 ]; then
  echo "✅ ALL_HEALTHY - проблем не найдено"
else
  echo "⚠️ Найдено проблем: $ERRORS"
fi
