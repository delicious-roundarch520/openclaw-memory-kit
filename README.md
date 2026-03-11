# OpenClaw Memory Kit

Полная система памяти и восстановления контекста для AI-агентов на OpenClaw.

Агент без памяти - как человек с амнезией. Каждая новая сессия начинается с чистого листа. Этот кит решает проблему: шаблоны файлов, кроны для автосохранения, скрипты для гигиены, конфиги для компактификации. Всё что нужно чтобы агент помнил.

---

## Быстрый старт (5 минут)

```bash
git clone https://github.com/AlekseiUL/openclaw-memory-kit.git
cd openclaw-memory-kit
bash install.sh
```

Скрипт:
1. Проверит что OpenClaw установлен
2. Спросит путь к workspace
3. Создаст структуру `memory/` (core, decisions, projects, archive)
4. Скопирует шаблоны (BOOTSTRAP.md, MEMORY.md, DO_NOT_DELETE.md, handoff.md)
5. Установит скрипты в `~/.openclaw/scripts/`
6. Покажет что дальше (какие сниппеты добавить в конфиг)

**install.sh НЕ меняет openclaw.json.** Только копирует файлы и показывает инструкции.

---

## Структура репо

```
openclaw-memory-kit/
├── README.md                    # Этот файл
├── LICENSE                      # MIT
├── install.sh                   # Автоустановка
│
├── templates/                   # Готовые шаблоны
│   ├── BOOTSTRAP.md             # Старт после компактификации
│   ├── MEMORY.md                # Долгосрочная память (пример)
│   ├── DO_NOT_DELETE.md         # Защита файлов
│   └── handoff.md               # Передача контекста
│
├── memory/                      # Структура папок памяти
│   ├── core/                    # Вечные факты
│   ├── decisions/               # Решения и правила
│   ├── projects/                # Проекты
│   └── archive/daily/           # Архив дневников
│
├── crons/                       # Промпты кронов
│   ├── auto-handoff.md          # 3x/день - сохранение контекста
│   ├── auto-diary.md            # 2x/день - дневник
│   ├── consolidator.md          # 1x/неделю - консолидация
│   └── night-cleanup.md         # 1x/ночь - уборка (0 токенов)
│
├── config/                      # Конфиг-сниппеты для openclaw.json
│   ├── compaction.json          # Компактификация (safeguard mode)
│   ├── memory-flush.json        # memoryFlush промпт
│   └── memory-search.json       # Векторный поиск (hybrid)
│
├── scripts/                     # Утилиты (bash, 0 токенов)
│   ├── health-check.sh          # Проверка здоровья системы
│   ├── consistency-check.sh     # Целостность данных
│   └── archive-old-notes.sh     # Архивация + ротация + cleanup
│
└── docs/                        # Документация
    ├── architecture.md          # Архитектура (5 слоёв памяти)
    ├── how-it-works.md          # Каждый компонент подробно
    ├── troubleshooting.md       # Решение проблем
    └── faq.md                   # Частые вопросы
```

---

## Компоненты

### Шаблоны (templates/)

| Файл | Зачем |
|------|-------|
| **BOOTSTRAP.md** | Инструкция для агента после пробуждения/компактификации. Читает handoff → daily note → sessions_history. Восстанавливает контекст. |
| **MEMORY.md** | Долгосрочная память. Грузится в каждую сессию. Держи < 3000 символов. Ключевые факты, приоритеты, решения. |
| **DO_NOT_DELETE.md** | Список файлов которые агент НЕ должен удалять. Защита от случайной чистки. |
| **handoff.md** | Передача контекста между сессиями. Формат: Тема, Решения, TODO, Файлы, Контекст, Черновики. |

### Кроны (crons/)

| Крон | Расписание | Модель | Зачем |
|------|------------|--------|-------|
| **auto-handoff** | 3x/день (12, 18, 23) | Sonnet | Сохраняет текущий контекст в handoff.md |
| **auto-diary** | 2x/день (13, 22) | Sonnet | Дневник дня в memory/YYYY-MM-DD.md |
| **consolidator** | Вс 03:00 | Sonnet | Извлекает паттерны из daily notes → core/, decisions/ |
| **night-cleanup** | 03:30 | bash (0 токенов) | Архивация, ротация логов, чистка сессий |

Каждый файл содержит промпт + готовый JSON для `openclaw.json → crons[]`.

### Конфиги (config/)

| Файл | Куда вставлять | Зачем |
|------|----------------|-------|
| **compaction.json** | `agents[].compaction` | Safeguard mode + memoryFlush перед сжатием |
| **memory-flush.json** | `compaction.memoryFlush.prompt` | Полный промпт для записи контекста |
| **memory-search.json** | `memorySearch` | Hybrid vector search (70% vector + 30% BM25) |

### Скрипты (scripts/)

| Скрипт | Зачем |
|--------|-------|
| **health-check.sh** | Проверка: файлы на месте, handoff актуален, SQLite WAL, gateway жив |
| **consistency-check.sh** | Поиск противоречий между файлами (размер MEMORY.md, дубликаты) |
| **archive-old-notes.sh** | Полная ночная уборка: архивация > 14д, удаление > 90д, ротация логов, чистка сессий, SQLite vacuum |

---

## Установка

### Автоматическая

```bash
bash install.sh
```

### Ручная

1. Скопируй шаблоны в workspace агента:
```bash
WS="$HOME/.openclaw/agents/main/agent"  # ваш путь
cp templates/BOOTSTRAP.md "$WS/"
cp templates/MEMORY.md "$WS/"
cp templates/DO_NOT_DELETE.md "$WS/memory/"
cp templates/handoff.md "$WS/memory/"
```

2. Создай структуру:
```bash
mkdir -p "$WS/memory/"{core,decisions,projects,archive/daily}
```

3. Скопируй скрипты:
```bash
mkdir -p ~/.openclaw/scripts
cp scripts/*.sh ~/.openclaw/scripts/
chmod +x ~/.openclaw/scripts/*.sh
```

---

## Настройка кронов

Добавь в `~/.openclaw/openclaw.json` → `agents` → `[ваш агент]` → `crons`:

```json
{
  "crons": [
    {
      "id": "auto-handoff",
      "name": "Auto Handoff",
      "schedule": "0 12,18,23 * * *",
      "sessionTarget": "isolated",
      "deleteAfterRun": true,
      "payload": {
        "kind": "agentTurn",
        "message": "Запиши текущий контекст в memory/handoff.md. Формат: ## Тема, ## Решения, ## TODO, ## Файлы, ## Контекст, ## Черновики. Только факты, точные пути. Если ничего - NO_REPLY.",
        "model": "anthropic/claude-sonnet-4-6",
        "timeoutSeconds": 120
      },
      "delivery": { "mode": "none" }
    },
    {
      "id": "auto-diary",
      "name": "Auto Diary",
      "schedule": "0 13,22 * * *",
      "sessionTarget": "isolated",
      "deleteAfterRun": true,
      "payload": {
        "kind": "agentTurn",
        "message": "Напиши дневник в memory/YYYY-MM-DD.md (текущая дата). Если файл есть - дополни. Формат: Что было, Решения, Инсайты. Max 200 слов. Если ничего - NO_REPLY.",
        "model": "anthropic/claude-sonnet-4-6",
        "timeoutSeconds": 120
      },
      "delivery": { "mode": "none" }
    },
    {
      "id": "weekly-consolidator",
      "name": "Weekly Consolidator",
      "schedule": "0 3 * * 0",
      "sessionTarget": "isolated",
      "deleteAfterRun": true,
      "payload": {
        "kind": "agentTurn",
        "message": "Консолидация: прочитай daily notes за 7 дней, извлеки паттерны, обнови memory/decisions/ и memory/core/. Проверь MEMORY.md < 3000 символов. Не перезаписывай - дополняй. Если ничего - NO_REPLY.",
        "model": "anthropic/claude-sonnet-4-6",
        "timeoutSeconds": 300
      },
      "delivery": { "mode": "none" }
    }
  ]
}
```

Полные промпты и детали - в `crons/*.md`.

---

## Конфиг-сниппеты

### Компактификация

Добавь в `agents[].compaction`:

```json
{
  "mode": "safeguard",
  "reserveTokensFloor": 25000,
  "maxHistoryShare": 0.7,
  "identifierPolicy": "strict",
  "model": "anthropic/claude-sonnet-4-6",
  "memoryFlush": {
    "enabled": true,
    "softThresholdTokens": 8000,
    "prompt": "ПЕРЕД компактификацией запиши в memory/handoff.md: ## Тема, ## Решения, ## TODO, ## Файлы, ## Контекст, ## Черновики. Точные пути, факты, черновики ЦЕЛИКОМ."
  }
}
```

### Векторный поиск

Добавь в корень `openclaw.json`:

```json
{
  "memorySearch": {
    "enabled": true,
    "sources": ["memory", "sessions"],
    "experimental": { "sessionMemory": true },
    "provider": "openai",
    "model": "text-embedding-3-small",
    "query": {
      "hybrid": {
        "enabled": true,
        "vectorWeight": 0.7,
        "textWeight": 0.3
      }
    }
  }
}
```

---

## FAQ

**Зачем handoff если есть memory_search?**
handoff - быстрый restore "чем занимались 5 минут назад". memory_search - глубокий поиск по всей базе. После компактификации нужен handoff.

**Можно без векторной памяти?**
Да. Базовая система (handoff + daily notes + MEMORY.md) работает без неё.

**Сколько жрут кроны?**
~4000-7000 токенов/день на Sonnet. Меньше $0.01/день.

**Как мигрировать?**
Скопируй файлы в memory/core/, создай MEMORY.md, настрой кроны. Подробнее - docs/faq.md.

Больше вопросов - [docs/faq.md](docs/faq.md).

---

## Документация

- [Архитектура](docs/architecture.md) - 5 слоёв памяти, потоки данных
- [Как работает](docs/how-it-works.md) - каждый компонент подробно
- [Решение проблем](docs/troubleshooting.md) - 8 типичных ситуаций
- [FAQ](docs/faq.md) - частые вопросы

---

## Лицензия

MIT - делай что хочешь.

---

# OpenClaw Memory Kit (English)

Complete memory and context persistence system for OpenClaw AI agents.

An agent without memory is like a person with amnesia. Every session starts from scratch. This kit solves the problem: file templates, auto-save crons, hygiene scripts, compaction configs. Everything your agent needs to remember.

## Quick Start

```bash
git clone https://github.com/AlekseiUL/openclaw-memory-kit.git
cd openclaw-memory-kit
bash install.sh
```

The installer checks for OpenClaw, asks for your workspace path, copies templates, creates the memory structure, and installs scripts. **It does NOT modify openclaw.json** - only shows what to add.

## What's Inside

- **templates/** - BOOTSTRAP.md (wake-up instructions), MEMORY.md (long-term memory), DO_NOT_DELETE.md (file protection), handoff.md (context transfer)
- **crons/** - Auto-handoff (3x/day), Auto-diary (2x/day), Weekly consolidator, Night cleanup (0 tokens)
- **config/** - Compaction (safeguard mode), memoryFlush prompt, Hybrid vector search
- **scripts/** - Health check, consistency check, archive/rotate/cleanup
- **docs/** - Architecture (5 memory layers), how each component works, troubleshooting, FAQ

## Architecture

```
Working Memory  → MEMORY.md, AGENTS.md (loaded every session)
Episodic Memory → daily notes, session history
Semantic Memory → memory/core/, vectorDB (hybrid search)
Procedural      → skills/, memory/decisions/
Handoff Layer   → handoff.md, BOOTSTRAP.md
```

See [docs/architecture.md](docs/architecture.md) for details.

## License

MIT
