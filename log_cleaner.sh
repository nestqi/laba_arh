#!/bin/bash

# Проверка аргументов
if [ $# -lt 2 ]; then
    echo "Использование: $0 <путь_до_папки> <порог_в_МБ>"
    exit 1
fi

THRESHOLD_PERCENT=80   # Архивируем, если папка заполнена более 80% от порога

FOLDER="$1"
THRESHOLD_MB="$2"
BACKUP_DIR="/backup"

# Создаем папку для бэкапов, если не существует
mkdir -p "$BACKUP_DIR"

# Получаем размер папки в байтах
FOLDER_SIZE_BYTES=$(du -sb "$FOLDER" | awk '{print $1}')
THRESHOLD_BYTES=$((THRESHOLD_MB * 1024 * 1024))

# Рассчитываем заполнение в %
PERCENT=$(( FOLDER_SIZE_BYTES * 100 / THRESHOLD_BYTES ))
echo "Папка '$FOLDER' заполнена на $PERCENT% от порога $THRESHOLD_MB МБ"

# Если превышен порог процентов, архивируем столько старых файлов, чтобы вернуться к порогу
if [ "$PERCENT" -ge "$THRESHOLD_PERCENT" ]; then
    echo "Порог $THRESHOLD_PERCENT% превышен! Архивируем старые файлы..."

    # Считаем количество байт, которое нужно освободить
    TARGET_BYTES=$(( THRESHOLD_BYTES * THRESHOLD_PERCENT / 100 ))
    EXCESS_BYTES=$(( FOLDER_SIZE_BYTES - TARGET_BYTES ))

    files_to_archive=()
    size_accum=0

    # Сортируем файлы по дате изменения (старые первыми)
    for f in $(ls -tr "$FOLDER"); do
        fsize=$(du -b "$FOLDER/$f" | awk '{print $1}')
        files_to_archive+=("$f")
        size_accum=$((size_accum + fsize))

        if [ $size_accum -ge $EXCESS_BYTES ]; then
            break
        fi
    done

    if [ ${#files_to_archive[@]} -eq 0 ]; then
        echo "Нет файлов для архивации."
        exit 0
    fi

    # Создаем архив
    ARCHIVE_NAME="archive_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$FOLDER" "${files_to_archive[@]}"

    # Удаляем заархивированные файлы
    for f in "${files_to_archive[@]}"; do
        rm -f "$FOLDER/$f"
    done

    echo "Архивация завершена: $ARCHIVE_NAME"
else
    echo "Порог $THRESHOLD_PERCENT% не превышен, архивирование не требуется."
fi

