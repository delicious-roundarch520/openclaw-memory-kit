# Автоматическая настройка OpenClaw Memory Kit

> Скорми этот файл своему агенту (скопируй текст в чат). Он выполнит все шаги сам.

---

Ты получил OpenClaw Memory Kit - систему памяти и восстановления контекста. Твоя задача - установить его в текущий workspace. Выполни шаги по порядку.

## ⚠️ ПЕРЕД НАЧАЛОМ - сделай бэкап конфига!

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup-$(date +%Y%m%d)
```

Если что-то пойдёт не так - всегда можно откатить:
```bash
cp ~/.openclaw/openclaw.json.backup-* ~/.openclaw/openclaw.json
openclaw gateway start
```

## Шаг 1. Клонируй репозиторий

```bash
git clone https://github.com/AlekseiUL/openclaw-memory-kit.git /tmp/openclaw-memory-kit
```

## Шаг 2. Запусти установку

```bash
bash /tmp/openclaw-memory-kit/install.sh
```

Когда спросит workspace - укажи путь к своему рабочему каталогу (тот что в конфиге `agents[].workspace`).

## Шаг 3. Примени конфиг компактификации

Прочитай файл `/tmp/openclaw-memory-kit/config/compaction.json` и примени эти настройки через:

```
gateway config.patch
```

Путь в конфиге: `agents.defaults.compaction`. Вот что нужно установить:

- `mode`: `"safeguard"`
- `reserveTokensFloor`: `25000`
- `maxHistoryShare`: `0.7`
- `identifierPolicy`: `"strict"`
- `model`: модель для компактификации (рекомендуется дешёвая). Примеры: `"anthropic/claude-sonnet-4-6"`, `"openai/gpt-4o-mini"`, `"google/gemini-2.5-flash"` - подставь ту что у тебя настроена
- `memoryFlush.enabled`: `true`
- `memoryFlush.softThresholdTokens`: `8000`
- `memoryFlush.prompt`: скопируй из файла `config/compaction.json` поле `memoryFlush.prompt`

## Шаг 3.5. Разреши кронам читать историю сессии

Кроны Auto Handoff и Auto Diary работают в isolated режиме. По умолчанию они видят только себя и **не могут** читать историю основной сессии. Нужно разрешить:

```
gateway config.patch
```

Путь: `tools.sessions.visibility`. Установи значение `"agent"`:

```json
{
  "tools": {
    "sessions": {
      "visibility": "agent"
    }
  }
}
```

> ⚠️ Без этой настройки кроны Auto Handoff и Auto Diary будут запускаться, но не смогут прочитать `sessions_history` основной сессии — результат будет пустым.

## Шаг 4. Создай кроны

> **Модель в кронах:** везде указан `anthropic/claude-sonnet-4-6`. Если у тебя другой провайдер - замени на свою модель. Примеры: `openai/gpt-4o-mini`, `google/gemini-2.5-flash`. Используй лёгкую (дешёвую) модель - кроны не требуют мощной.

Создай 3 крона через `cron add`:

### 4.1 Auto Handoff (3 раза в день)

```json
{
  "name": "Auto Handoff",
  "schedule": { "kind": "cron", "expr": "0 12,18,23 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Проверь sessions_history(limit=10). Если за последние 2 часа была активность - запиши контекст в memory/handoff.md. Формат:\n\n## Тема\n[Над чем работали]\n\n## Решения\n- [Что решили и почему]\n\n## TODO\n- [ ] [Незавершённое]\n\n## Файлы\n- `путь` - зачем\n\n## Контекст\n[Факты для продолжения. СУТЬ, не номера сообщений.]\n\n## Черновики\n[Незаконченный текст - ЦЕЛИКОМ]\n\nЕсли активности не было - NO_REPLY.",
    "model": "anthropic/claude-sonnet-4-6",
    "timeoutSeconds": 120
  },
  "delivery": { "mode": "none" }
}
```

### 4.2 Auto Diary (2 раза в день)

```json
{
  "name": "Auto Diary",
  "schedule": { "kind": "cron", "expr": "0 13,22 * * *" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Напиши дневник дня в memory/YYYY-MM-DD.md (подставь текущую дату). Если файл есть - дополни новой секцией с временной меткой. Формат:\n\n## HH:MM - краткое описание\n- Что сделали\n- Решения\n- Инсайты\n\nМаксимум 200 слов. Если за день ничего не было - NO_REPLY.",
    "model": "anthropic/claude-sonnet-4-6",
    "timeoutSeconds": 120
  },
  "delivery": { "mode": "none" }
}
```

### 4.3 Weekly Consolidator (раз в неделю)

```json
{
  "name": "Weekly Consolidator",
  "schedule": { "kind": "cron", "expr": "0 3 * * 0" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "Еженедельная консолидация памяти:\n1. Прочитай все daily notes за последние 7 дней (memory/YYYY-MM-DD.md)\n2. Извлеки повторяющиеся паттерны и важные решения\n3. Обнови memory/core/ и memory/decisions/ если есть новые факты/правила\n4. Проверь MEMORY.md - не превышает ли 3000 символов. Если да - вынеси детали в core/\n5. Не перезаписывай существующее - дополняй\n\nЕсли ничего нового - NO_REPLY.",
    "model": "anthropic/claude-sonnet-4-6",
    "timeoutSeconds": 300
  },
  "delivery": { "mode": "none" }
}
```

## Шаг 5. Включи векторный поиск (опционально)

Если у тебя есть OpenAI API ключ, примени настройки из `/tmp/openclaw-memory-kit/config/memory-search.json` через `gateway config.patch`. Путь: `memorySearch`.

Если нет - пропусти. Базовая система работает и без него.

## Шаг 6. Проверь

```bash
bash ~/.openclaw/scripts/health-check.sh
```

## Шаг 7. Убери за собой

```bash
rm -rf /tmp/openclaw-memory-kit
```

---

## Готово

После этих шагов:
- BOOTSTRAP.md загрузится автоматически при каждом старте
- memoryFlush запишет контекст перед компактификацией
- Кроны будут сохранять handoff и дневник автоматически
- Консолидатор раз в неделю извлечёт паттерны

Система памяти работает. Агент помнит.
