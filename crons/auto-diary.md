# Auto-Diary - Крон дневника дня

> Запускать 2 раза в день: 13:00 (полдень), 22:00 (вечер)
> Модель: лёгкая (Sonnet / GPT-4o-mini)
>
> ⚠️ **Требует** `tools.sessions.visibility: "agent"` в конфиге. Без этого isolated крон не сможет читать `sessions_history`.

## Промпт для крона

```
Напиши дневник дня в memory/YYYY-MM-DD.md (подставь текущую дату).

Если файл уже есть - ДОПОЛНИ (не перезаписывай). Добавь новый блок с timestamp.

Формат:

### [HH:MM] Обновление

**Что было:**
- [Ключевые события/задачи]

**Решения:**
- [Что решили и почему]

**Инсайты:**
- [Что узнал нового, паттерны]

Правила:
- Только факты, без "прошёл замечательный день"
- Конкретные файлы и пути если работали с ними
- Если ничего не происходило - NO_REPLY
- Максимум 200 слов на обновление
```

## Конфиг для openclaw.json

```json
{
  "id": "auto-diary",
  "name": "Auto Diary",
  "schedule": "0 13,22 * * *",
  "sessionTarget": "isolated",
  "deleteAfterRun": true,
  "payload": {
    "kind": "agentTurn",
    "message": "Напиши дневник дня в memory/YYYY-MM-DD.md (текущая дата). Если файл есть - дополни с timestamp. Формат: Что было, Решения, Инсайты. Только факты, max 200 слов. Если ничего - NO_REPLY.",
    "model": "anthropic/claude-sonnet-4-6",
    "_model_hint": "Замени на свою модель. Примеры: anthropic/claude-sonnet-4-6, openai/gpt-4o-mini, google/gemini-2.5-flash",
    "timeoutSeconds": 120
  },
  "delivery": {
    "mode": "none"
  }
}
```
