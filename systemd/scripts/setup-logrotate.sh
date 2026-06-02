#!/bin/bash
# Скрипт настройки ротации логов для Angie Proxy
# Запускается от root

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
LOGROTATE_CONF="/etc/logrotate.d/angie-proxy"

echo "Настройка ротации логов Angie Proxy..."

# Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: скрипт должен быть запущен от root"
    exit 1
fi

# Проверка наличия logrotate
if ! command -v logrotate &> /dev/null; then
    echo "logrotate не найден. Установка..."
    apt-get update
    apt-get install -y logrotate
fi

# Определяем абсолютный путь к логам
LOG_DIR="$(cd "$PROJECT_DIR" && pwd)/logs"

# Проверка существования директории для логов
if [ ! -d "$LOG_DIR" ]; then
    echo "Ошибка: директория для логов не найдена: $LOG_DIR"
    exit 1
fi

# Генерируем конфигурацию logrotate с абсолютным путём
echo "Генерация конфигурации logrotate для: $LOG_DIR"
cat > "$LOGROTATE_CONF" << EOF
# Конфигурация ротации логов Angie Proxy
# Сгенерировано: $(date)
# Проект: $PROJECT_DIR

$LOG_DIR/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 root docker
    sharedscripts
    postrotate
        # Сигнал контейнеру Angie для переоткрытия логов
        /usr/bin/docker exec angie-proxy angie -s reopen 2>/dev/null || true
    endscript
}
EOF

chmod 644 "$LOGROTATE_CONF"

# Тестирование конфигурации
echo "Тестирование конфигурации logrotate..."
if logrotate -d "$LOGROTATE_CONF" &> /dev/null; then
    echo "✓ Конфигурация logrotate проверена успешно"
else
    echo "✗ Ошибка в конфигурации logrotate"
    exit 1
fi

echo "✓ Настройка ротации логов завершена"
echo ""
echo "Параметры ротации:"
echo "  - Частота: ежедневно"
echo "  - Хранение: 14 дней"
echo "  - Сжатие: включено"
echo "  - Путь к логам: $LOG_DIR"
echo ""
echo "Для ручной ротации выполните:"
echo "  sudo logrotate -f $LOGROTATE_CONF"