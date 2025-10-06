param(
    [Parameter(Mandatory=$true)]
    [string]$LogFolder,
    
    [Parameter(Mandatory=$true)]
    [int]$ThresholdMB,
    
    [Parameter(Mandatory=$true)]
    [int]$ThresholdPercent,
    
    [Parameter(Mandatory=$true)]
    [int]$FilesToArchive,
    
    [string]$BackupFolder = "C:\backup"
)

# Создаем папку для бэкапов
if (!(Test-Path $BackupFolder)) {
    New-Item -ItemType Directory -Path $BackupFolder -Force
}

# Получаем размер папки в байтах
$folderSize = (Get-ChildItem $LogFolder -Recurse | Measure-Object -Property Length -Sum).Sum
$thresholdBytes = $ThresholdMB * 1024 * 1024

# Рассчитываем заполнение в %
if ($thresholdBytes -eq 0) {
    $percent = 0
} else {
    $percent = [math]::Round(($folderSize / $thresholdBytes) * 100, 2)
}

Write-Host "Папка '$LogFolder' заполнена на $percent% от порога $ThresholdMB МБ"
Write-Host "Размер папки: $([math]::Round($folderSize / 1024 / 1024, 2)) МБ"

# Если превышен порог процентов, архивируем старые файлы
if ($percent -ge $ThresholdPercent) {
    Write-Host "Порог $ThresholdPercent% превышен! Архивируем $FilesToArchive старых файлов..."
    
    # Получаем M самых старых файлов
    $oldestFiles = Get-ChildItem $LogFolder -File | 
                   Sort-Object LastWriteTime | 
                   Select-Object -First $FilesToArchive
    
    if ($oldestFiles.Count -eq 0) {
        Write-Host "Нет файлов для архивации."
        exit 0
    }
    
    # Создаем имя архива с timestamp
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $archiveName = "archive_${timestamp}_M${FilesToArchive}.zip"
    $archivePath = Join-Path $BackupFolder $archiveName
    
    # Архивируем файлы
    try {
        Compress-Archive -Path $oldestFiles.FullName -DestinationPath $archivePath -Force
        Write-Host "Архив создан: $archivePath"
        
        # Удаляем заархивированные файлы
        foreach ($file in $oldestFiles) {
            Remove-Item $file.FullName -Force
            Write-Host "Удален: $($file.Name)"
        }
        
        Write-Host "Архивация завершена. Удалено файлов: $($oldestFiles.Count)"
    }
    catch {
        Write-Error "Ошибка при архивации: $_"
        exit 1
    }
} else {
    Write-Host "Порог $ThresholdPercent% не превышен, архивирование не требуется."
}
