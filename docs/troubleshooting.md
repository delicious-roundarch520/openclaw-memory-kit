# Решение проблем

## 1. "Агент забывает контекст после компактификации"

**Симптом:** После длинного разговора агент вдруг забыл о чём шла речь.

**Причина:** Контекст был сжат, handoff пустой или устаревший.

**Решение:**
1. Проверь handoff: `cat memory/handoff.md`
2. Если пустой - memoryFlush не настроен. Добавь compaction config из `config/compaction.json`
3. Если устаревший - крон auto-handoff не работает. Проверь: `openclaw cron list`
4. Ручной запуск: попроси агента "запиши текущий контекст в handoff.md"

## 2. "Handoff пустой"

**Симптом:** handoff.md содержит шаблон или "Нет активных задач".

**Причина:** Крон auto-handoff не находит активных задач (или не работает).

**Решение:**
```bash
# Проверь что крон зарегистрирован
openclaw cron list | grep handoff

# Проверь логи последнего запуска
openclaw sessions list --kinds cron --limit 5
```

Если крон не найден - добавь конфиг из `crons/auto-handoff.md`.

## 3. "memory_search ничего не находит"

**Симптом:** Агент говорит "не нашёл в памяти" хотя факт точно был записан.

**Причина:**
- Файл не проиндексирован (новый файл)
- Запрос слишком отличается от текста (семантический gap)
- Память не настроена

**Решение:**
```bash
# Проверь статус индекса
openclaw memory status

# Принудительная переиндексация
openclaw memory index --force

# Проверь что memorySearch включён в openclaw.json
cat ~/.openclaw/openclaw.json | grep -A5 memorySearch
```

## 4. "MEMORY.md слишком большой"

**Симптом:** Агент медленно отвечает, токены расходуются быстро.

**Причина:** MEMORY.md > 3000 символов. Он грузится в каждую сессию.

**Решение:**
```bash
# Проверь размер
wc -c MEMORY.md

# Если > 3000 - сожми:
# 1. Перенеси детали в memory/core/ (они доступны через memory_search)
# 2. Оставь в MEMORY.md только самое важное
# 3. Консолидатор делает это автоматически - но можно вручную
```

## 5. "WAL mode сброшен"

**Симптом:** Векторный поиск медленный или ошибки при записи.

**Причина:** SQLite сбросил WAL mode (другой процесс открыл базу, или crash).

**Решение:**
```bash
# Проверь текущий режим
sqlite3 ~/.openclaw/memory/main.sqlite "PRAGMA journal_mode;"

# Если не wal - включи:
sqlite3 ~/.openclaw/memory/main.sqlite "PRAGMA journal_mode=WAL;"

# Убедись что никто ещё не держит файл:
lsof | grep main.sqlite
```

## 6. "Daily notes копятся, не архивируются"

**Симптом:** В memory/ лежат daily notes за месяц+.

**Причина:** Ночной скрипт не настроен или не запускается.

**Решение:**
```bash
# Ручная архивация
bash scripts/archive-old-notes.sh

# Настрой автозапуск - см. crons/night-cleanup.md
```

## 7. "Логи занимают много места"

**Симптом:** /tmp/openclaw/ или ~/.openclaw/logs/ занимают гигабайты.

**Решение:**
```bash
# Проверь размер
du -sh ~/.openclaw/logs/ /tmp/openclaw/

# Ручная очистка
find ~/.openclaw/logs -name "*.log" -size +10M -exec sh -c 'tail -1000 "$1" > "$1.tmp" && mv "$1.tmp" "$1"' _ {} \;
find /tmp/openclaw -name "*.log" -mtime +7 -delete
```

## 8. "Агент не выполняет BOOTSTRAP.md"

**Симптом:** После компактификации агент не читает handoff, начинает с нуля.

**Причина:** BOOTSTRAP.md не в workspace или повреждён.

**Решение:**
```bash
# Проверь что файл на месте
ls -la BOOTSTRAP.md

# Проверь что он в workspace files OpenClaw
# BOOTSTRAP.md должен лежать в корне workspace агента
```

---

## 8. "Auto Handoff пишет пустой handoff / не видит историю сессии"

**Симптом:** Крон Auto Handoff запускается (status: ok), но handoff.md пустой или содержит "нет данных".

**Причина:** Isolated кроны по умолчанию имеют `visibility: "tree"` — видят только свою сессию. Вызов `sessions_history("agent:main:main")` возвращает ошибку доступа.

**Решение:** Добавь в конфиг (`~/.openclaw/openclaw.json`):

```json
"tools": {
  "sessions": {
    "visibility": "agent"
  }
}
```

Перезапусти gateway. Значение `"agent"` разрешает видеть все сессии того же агента.
