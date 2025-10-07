
$LogFolder = "C:\test_logs"
$BackupFolder = "C:\backup"

Write-Host "    Тест скрипта очистки логов для Windows    "

# Очищаем и создаем тестовые папки
Write-Host "Создаю тестовые папки..."
if (Test-Path $LogFolder) {
    Remove-Item $LogFolder -Recurse -Force
}
if (Test-Path $BackupFolder) {
    Remove-Item $BackupFolder -Recurse -Force
}

New-Item -ItemType Directory -Path $LogFolder -Force
New-Item -ItemType Directory -Path $BackupFolder -Force

# Создаем тестовые файлы ЕЩЕ БОЛЬШЕГО размера
Write-Host "Создаю тестовые файлы..."
for ($i = 1; $i -le 10; $i++) {
    $fileName = "log_$i.txt"
    $filePath = Join-Path $LogFolder $fileName
    
    # СОЗДАЕМ ОЧЕНЬ БОЛЬШИЕ ФАЙЛЫ (5-10 МБ каждый)
    $fileSizeMB = Get-Random -Minimum 5 -Maximum 10
    $fileSizeBytes = $fileSizeMB * 1024 * 1024
    
    # Создаем файл случайного содержимого
    $content = [System.Text.Encoding]::ASCII.GetBytes(("x" * $fileSizeBytes))
    [System.IO.File]::WriteAllBytes($filePath, $content)
    
    # Устанавливаем разное время модификации (старые файлы)
    $oldDate = (Get-Date).AddHours(-$i * 2)
    (Get-Item $filePath).LastWriteTime = $oldDate
    
    Write-Host "Создан: $fileName ($fileSizeMB МБ)"
}

# Создаем несколько файлов с пробелами в именах
Write-Host "Создаю файлы с пробелами в именах..."
$filesWithSpaces = @(
    "my log file.txt",
    "another test file.log", 
    "file with spaces.dat"
)

foreach ($file in $filesWithSpaces) {
    $filePath = Join-Path $LogFolder $file
    $fileSizeMB = 8  # 8 МБ каждый
    $fileSizeBytes = $fileSizeMB * 1024 * 1024
    
    $content = [System.Text.Encoding]::ASCII.GetBytes(("y" * $fileSizeBytes))
    [System.IO.File]::WriteAllBytes($filePath, $content)
    
    (Get-Item $filePath).LastWriteTime = (Get-Date).AddHours(-25)
    Write-Host "Создан: $file (8 МБ)"
}

# ИЗМЕНЯЕМ ПАРАМЕТРЫ ДЛЯ ТЕСТА - уменьшаем порог
$ThresholdMB = 30      # Уменьшаем порог до 30 МБ
$ThresholdPercent = 80
$FilesToArchive = 5

# Получаем размер папки до архивации
$folderSizeBefore = (Get-ChildItem $LogFolder -Recurse | Measure-Object -Property Length -Sum).Sum
$thresholdBytes = $ThresholdMB * 1024 * 1024

if ($thresholdBytes -eq 0) {
    $percentBefore = 0
} else {
    $percentBefore = [math]::Round(($folderSizeBefore / $thresholdBytes) * 100, 2)
}

Write-Host ""
Write-Host "    СОСТОЯНИЕ ДО АРХИВАЦИИ    "
Write-Host "Папка: $LogFolder"
Write-Host "Порог: $ThresholdMB МБ"
Write-Host "Размер папки: $([math]::Round($folderSizeBefore / 1024 / 1024, 2)) МБ"
Write-Host "Заполнение: $percentBefore% от порога"

Write-Host ""
Write-Host "Файлы в папке (первые 10 по дате изменения):"
Get-ChildItem $LogFolder | Sort-Object LastWriteTime | Select-Object -First 10 | Format-Table Name, LastWriteTime, @{Name="Size(MB)"; Expression={[math]::Round($_.Length/1024/1024, 2)}}

# Запуск основного скрипта
Write-Host ""
Write-Host "    ЗАПУСК ОСНОВНОГО СКРИПТА    "
if ($percentBefore -ge $ThresholdPercent) {
    Write-Host "Порог $ThresholdPercent% превышен! Запускаю log_cleaner.ps1..."
    .\log_cleaner.ps1 -LogFolder $LogFolder -ThresholdMB $ThresholdMB -ThresholdPercent $ThresholdPercent -FilesToArchive $FilesToArchive -BackupFolder $BackupFolder
} else {
    Write-Host "Порог $ThresholdPercent% не достигнут, архивирование не требуется."
    Write-Host "Текущее заполнение: $percentBefore%, нужно: >= $ThresholdPercent%"
    
    # АВТОМАТИЧЕСКИ ЗАПУСКАЕМ С ДРУГИМИ ПАРАМЕТРАМИ
    Write-Host ""
    Write-Host "    АВТОМАТИЧЕСКИЙ ЗАПУСК С ПОНИЖЕННЫМ ПОРОГОМ     "
    .\log_cleaner.ps1 -LogFolder $LogFolder -ThresholdMB $ThresholdMB -ThresholdPercent 70 -FilesToArchive 3 -BackupFolder $BackupFolder
}

# Проверка результатов
Write-Host ""
Write-Host "    РЕЗУЛЬТАТЫ АРХИВАЦИИ    "
Write-Host "Содержимое папки backup:"
if (Test-Path $BackupFolder) {
    Get-ChildItem $BackupFolder | Format-Table Name, @{Name="Size(MB)"; Expression={[math]::Round($_.Length/1024/1024, 2)}}, LastWriteTime
} else {
    Write-Host "Бэкап директория пуста"
}

Write-Host ""
Write-Host "Оставшиеся файлы в лог папке:"
if (Test-Path $LogFolder) {
    $remainingFiles = Get-ChildItem $LogFolder | Sort-Object LastWriteTime
    $remainingFiles | Select-Object -First 10 | Format-Table Name, LastWriteTime, @{Name="Size(MB)"; Expression={[math]::Round($_.Length/1024/1024, 2)}}
    Write-Host "Всего файлов осталось: $($remainingFiles.Count)"
} else {
    Write-Host "Лог директория пуста"
}

# Размер папки после архивации
if (Test-Path $LogFolder) {
    $folderSizeAfter = (Get-ChildItem $LogFolder -Recurse | Measure-Object -Property Length -Sum).Sum
    if ($thresholdBytes -eq 0) {
        $percentAfter = 0
    } else {
        $percentAfter = [math]::Round(($folderSizeAfter / $thresholdBytes) * 100, 2)
    }
} else {
    $folderSizeAfter = 0
    $percentAfter = 0
}

Write-Host ""
Write-Host "      ИТОГИ      "
Write-Host "Размер до: $([math]::Round($folderSizeBefore / 1024 / 1024, 2)) МБ ($percentBefore%)"
Write-Host "Размер после: $([math]::Round($folderSizeAfter / 1024 / 1024, 2)) МБ ($percentAfter%)"

if ($folderSizeBefore -gt $folderSizeAfter) {
    Write-Host "Освобождено: $([math]::Round(($folderSizeBefore - $folderSizeAfter) / 1024 / 1024, 2)) МБ"
    Write-Host ""
    Write-Host "ТЕСТ ПРОЙДЕН: Архивация выполнена успешно!"
} else {
    Write-Host "Освобождено: 0 МБ"
    Write-Host ""
    Write-Host "ТЕСТ: Архивация не потребовалась"
}
