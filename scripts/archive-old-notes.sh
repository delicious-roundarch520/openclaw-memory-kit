#!/bin/bash
# archive-old-notes.sh - Архивация и очистка daily notes
# Часть ночной уборки. Можно запускать отдельно.
set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/agents/main/agent}"
MEMORY_DIR="$WORKSPACE/memory"
ARCHIVE_DIR="$MEMORY_DIR/archive/daily"
LOG_DIR="$HOME/.openclaw/logs"
TMP_LOG_DIR="/tmp/openclaw"
SQLITE_DB="$HOME/.openclaw/memory/main.sqlite"

ARCHIVE_AFTER_DAYS="${ARCHIVE_AFTER_DAYS:-14}"
PURGE_AFTER_DAYS="${PURGE_AFTER_DAYS:-90}"
LOG_MAX_MB="${LOG_MAX_MB:-10}"

log() { echo "$(date '+%H:%M:%S') $1"; }

# === 1. АРХИВАЦИЯ DAILY NOTES ===
log "📚 Архивация daily notes..."
mkdir -p "$ARCHIVE_DIR"

ARCHIVED=0
DELETED=0

for f in "$MEMORY_DIR"/20??-*.md; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  [[ "$fname" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]] || continue

  file_date="${fname%.md}"
  # Совместимость macOS/Linux
  if date -v-1d '+%Y' >/dev/null 2>&1; then
    cutoff_archive=$(date -v-${ARCHIVE_AFTER_DAYS}d '+%Y-%m-%d')
    cutoff_purge=$(date -v-${PURGE_AFTER_DAYS}d '+%Y-%m-%d')
  else
    cutoff_archive=$(date -d "${ARCHIVE_AFTER_DAYS} days ago" '+%Y-%m-%d')
    cutoff_purge=$(date -d "${PURGE_AFTER_DAYS} days ago" '+%Y-%m-%d')
  fi

  if [[ "$file_date" < "$cutoff_purge" ]]; then
    rm -f "$f" && DELETED=$((DELETED+1))
    log "  🗑️ Удалён (>$PURGE_AFTER_DAYS д): $fname"
  elif [[ "$file_date" < "$cutoff_archive" ]]; then
    mv "$f" "$ARCHIVE_DIR/$fname" && ARCHIVED=$((ARCHIVED+1))
    log "  📦 Архивирован (>$ARCHIVE_AFTER_DAYS д): $fname"
  fi
done

# Удаляем из архива старше PURGE_AFTER_DAYS
for f in "$ARCHIVE_DIR"/*.md; do
  [ -f "$f" ] || continue
  fname=$(basename "$f")
  [[ "$fname" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$ ]] || continue
  file_date="${fname%.md}"
  if [[ "$file_date" < "$cutoff_purge" ]]; then
    rm -f "$f" && DELETED=$((DELETED+1))
    log "  🗑️ Удалён из архива: $fname"
  fi
done

log "  ✅ Memory: archived=$ARCHIVED deleted=$DELETED"

# === 2. РОТАЦИЯ ЛОГОВ ===
log "🔄 Ротация логов..."
ROTATED=0

for f in "$LOG_DIR"/*.log "$LOG_DIR"/*.jsonl; do
  [ -f "$f" ] || continue
  size_mb=$(du -m "$f" 2>/dev/null | cut -f1)
  if [ "${size_mb:-0}" -ge "$LOG_MAX_MB" ]; then
    tail -1000 "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    ROTATED=$((ROTATED+1))
    log "  ✂️ $(basename "$f"): ${size_mb}MB → 1000 строк"
  fi
done

if [ -d "$TMP_LOG_DIR" ]; then
  find "$TMP_LOG_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null
  log "  🧹 tmp логи старше 7д удалены"
fi

log "  ✅ Logs: rotated=$ROTATED"

# === 3. ОЧИСТКА СТАРЫХ СЕССИЙ ===
log "🤖 Очистка старых сессий..."
SESSION_CLEANED=0
for agent_dir in "$HOME/.openclaw/agents"/*/sessions; do
  [ -d "$agent_dir" ] || continue
  for f in "$agent_dir"/*.jsonl; do
    [ -f "$f" ] || continue
    if stat -f %m "$f" >/dev/null 2>&1; then
      file_age=$(( ( $(date +%s) - $(stat -f %m "$f") ) / 86400 ))
    else
      file_age=$(( ( $(date +%s) - $(stat -c %Y "$f") ) / 86400 ))
    fi
    if [ "$file_age" -ge 30 ]; then
      rm -f "$f" && SESSION_CLEANED=$((SESSION_CLEANED+1))
    fi
  done
done
log "  ✅ Sessions: cleaned=$SESSION_CLEANED"

# === 4. SQLITE CLEANUP ===
if [ -f "$SQLITE_DB" ]; then
  log "🧹 SQLite cleanup..."
  BEFORE=$(du -m "$SQLITE_DB" | cut -f1)
  sqlite3 "$SQLITE_DB" "DELETE FROM embedding_cache;" 2>/dev/null || true
  sqlite3 "$SQLITE_DB" "VACUUM;" 2>/dev/null || true
  AFTER=$(du -m "$SQLITE_DB" | cut -f1)
  log "  ✅ SQLite: ${BEFORE}MB → ${AFTER}MB"
fi

# === ИТОГ ===
TOTAL=$((ARCHIVED + DELETED + ROTATED + SESSION_CLEANED))
log "✅ Готово: archived=$ARCHIVED deleted=$DELETED rotated=$ROTATED sessions=$SESSION_CLEANED total=$TOTAL"
