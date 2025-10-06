#!/bin/bash

LOG_DIR="/log"
BACKUP_DIR="/backup"

echo "Создаю тестовые папки..."
sudo rm -rf "$LOG_DIR" "$BACKUP_DIR"
sudo mkdir -p "$LOG_DIR"
sudo mkdir -p "$BACKUP_DIR"

echo "Создаю тестовые файлы..."
for i in {1..20}; do
    dd if=/dev/zero of="$LOG_DIR/log_$i.txt" bs=1K count=$((RANDOM % 200 + 50)) status=none
    sleep 0.1
done

# Порог в МБ для теста
THRESHOLD_MB=2
# Порог процентов, при котором срабатывает архивация
THRESHOLD_PERCENT=80

# --- Размер папки до запуска ---
FOLDER_SIZE_BYTES=$(du -sb "$LOG_DIR" | awk '{print $1}')
THRESHOLD_BYTES=$((THRESHOLD_MB * 1024 * 1024))
PERCENT=$(( FOLDER_SIZE_BYTES * 100 / THRESHOLD_BYTES ))
echo "Папка '$LOG_DIR' перед архивацией заполнена на $PERCENT% от порога $THRESHOLD_MB МБ"

# Запуск основного скрипта, если превышен порог процентов
if [ "$PERCENT" -ge "$THRESHOLD_PERCENT" ]; then
    echo
    echo "Порог $THRESHOLD_PERCENT% превышен! Запускаю log_cleaner.sh..."
    bash log_cleaner.sh "$LOG_DIR" "$THRESHOLD_MB"
else
    echo
    echo "Порог $THRESHOLD_PERCENT% не достигнут, архивирование не требуется."
fi

# --- Проверка результата ---
echo
echo "Содержимое $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"

echo
echo "Оставшиеся файлы в $LOG_DIR:"
ls -lh "$LOG_DIR"

# --- Размер папки после архивации ---
FOLDER_SIZE_BYTES=$(du -sb "$LOG_DIR" | awk '{print $1}')
PERCENT=$(( FOLDER_SIZE_BYTES * 100 / THRESHOLD_BYTES ))
echo
echo "Папка '$LOG_DIR' после архивации заполнена на $PERCENT% от порога $THRESHOLD_MB МБ"

