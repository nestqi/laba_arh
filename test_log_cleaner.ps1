$LogFolder = "C:\test_logs"
$BackupFolder = "C:\backup"

Write-Host "=== Тест скрипта очистки логов для Windows ==="

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

# Создаем тестовые файлы
Write-Host "Создаю тестовые файлы..."
for ($i = 1; $i -le 20; $i++) {
    $fileName = "log_$i.txt"
    $filePath = Join-Path $LogFolder $fileName
    
    # Создаем файл со случайным содержимым
    $content = "Лог файл #$i - " + ("x" * (Get-Random -Minimum 100 -Maximum 5000))
    Set-Content -Path $filePath -Value $content
    
    # Устанавливаем разное время модификации (старые файлы)
    $oldDate = (Get-Date).AddHours(-$i * 2)
    (Get-Item $filePath).LastWriteTime = $oldDate
    
    Write-Host "Создан: $fileName"
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
    Set-Content -Path $filePath -Value "Тестовый файл с пробелами: $file"
    (Get-Item $filePath).LastWriteTime = (Get-Date).AddHours(-25)
}

# Параметры для теста
$ThresholdMB = 2
$ThresholdPercent = 80
$FilesToArchive = 5

# Получаем размер папки до архивации
$folderSizeBefore = (Get-ChildItem $LogFolder -Recurse | Measure-Object -Property Length -Sum).Sum
$thresholdBytes = $ThresholdMB * 1024 * 1024
$percentBefore = [math]::Round(($folderSizeBefore / $thresholdBytes) * 100, 2)

Write-Host "`n=== СОСТОЯНИЕ ДО АРХИВАЦИИ ==="
Write-Host "Папка: $LogFolder"
Write-Host "Порог: $ThresholdMB МБ"
Write-Host "Размер папки: $([math]::Round($folderSizeBefore / 1024 / 1024, 2)) МБ"
Write-Host "Заполнение: $percentBefore% от порога"

Write-Host "`nФайлы в папке (первые 10 по дате изменения):"
Get-ChildItem $LogFolder | Sort-Object LastWriteTime | Select-Object -First 10 | Format-Table Name, LastWriteTime, @{Name="Size(KB)"; Expression={[math]::Round($_.Length/1024, 2)}}

# Запуск основного скрипта
Write-Host "`n=== ЗАПУСК ОСНОВНОГО СКРИПТА ==="
if ($percentBefore -ge $ThresholdPercent) {
    Write-Host "Порог $ThresholdPercent% превышен! Запускаю log_cleaner.ps1..."
    .\log_cleaner.ps1 -LogFolder $LogFolder -ThresholdMB $ThresholdMB -ThresholdPercent $ThresholdPercent -FilesToArchive $FilesToArchive -BackupFolder $BackupFolder
} else {
    Write-Host "Порог $ThresholdPercent% не достигнут, архивирование не требуется."
}

# Проверка результатов
Write-Host "`n=== РЕЗУЛЬТАТЫ АРХИВАЦИИ ==="
Write-Host "Содержимое $BackupFolder :"
if (Test-Path $BackupFolder) {
    Get-ChildItem $BackupFolder | Format-Table Name, Length, LastWriteTime
} else {
    Write-Host "Бэкап директория пуста"
}

Write-Host "`nОставшиеся файлы в $LogFolder :"
if (Test-Path $LogFolder) {
    Get-ChildItem $LogFolder | Sort-Object LastWriteTime | Select-Object -First 10 | Format-Table Name, LastWriteTime, @{Name="Size(KB)"; Expression={[math]::Round($_.Length/1024, 2)}}
} else {
    Write-Host "Лог директория пуста"
}

# Размер папки после архивации
if (Test-Path $LogFolder) {
    $folderSizeAfter = (Get-ChildItem $LogFolder -Recurse | Measure-Object -Property Length -Sum).Sum
    $percentAfter = [math]::Round(($folderSizeAfter / $thresholdBytes) * 100, 2)
} else {
    $folderSizeAfter = 0
    $percentAfter = 0
}

Write-Host "`n=== ИТОГИ ==="
Write-Host "Размер до: $([math]::Round($folderSizeBefore / 1024 / 1024, 2)) МБ ($percentBefore%)"
Write-Host "Размер после: $([math]::Round($folderSizeAfter / 1024 / 1024, 2)) МБ ($percentAfter%)"
Write-Host "Освобождено: $([math]::Round(($folderSizeBefore - $folderSizeAfter) / 1024 / 1024, 2)) МБ"

# Проверка успешности
if ($percentAfter -le $ThresholdPercent) {
    Write-Host "ТЕСТ ПРОЙДЕН: Размер папки уменьшен до $percentAfter%"
} else {
    Write-Host "`ТЕСТ НЕ ПРОЙДЕН: Размер папки $percentAfter% все еще превышает порог $ThresholdPercent%"
}
