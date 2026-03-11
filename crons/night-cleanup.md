# Night Cleanup - Ночная уборка

> Запускать каждую ночь: 03:30
> Это bash-скрипт, НЕ LLM крон. 0 токенов.

## Что делает

1. **Архивация daily notes** - старше 14 дней переносит в `memory/archive/daily/`
2. **Удаление старых архивов** - старше 90 дней удаляет из архива
3. **Ротация логов** - файлы > 10 МБ обрезает до 1000 строк
4. **Чистка tmp логов** - старше 7 дней
5. **Чистка старых сессий** - jsonl старше 30 дней
6. **Очистка embedding_cache** в SQLite (освобождает место)

## Запуск

Скрипт: `scripts/night-cleanup.sh`

### macOS (LaunchAgent)

```bash
cat > ~/Library/LaunchAgents/com.openclaw.night-cleanup.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.openclaw.night-cleanup</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-c</string>
    <string>$HOME/.openclaw/scripts/night-cleanup.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>3</integer>
    <key>Minute</key>
    <integer>30</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>/tmp/night-cleanup-stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/night-cleanup-stderr.log</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.openclaw.night-cleanup.plist
```

### Linux (crontab)

```bash
# Добавить в crontab -e:
30 3 * * * $HOME/.openclaw/scripts/night-cleanup.sh >> /tmp/night-cleanup.log 2>&1
```
