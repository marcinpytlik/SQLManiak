param(
    [int]$Iterations = 360,
    [int]$DelaySeconds = 60,
    [string]$LogPath = ".\output\collector-run.log"
)

$pythonExe = ".\.venv\Scripts\python.exe"
$moduleName = "src.collector.collector"

if (-not (Test-Path ".\output")) {
    New-Item -ItemType Directory -Path ".\output" | Out-Null
}

"==================================================" | Out-File -FilePath $LogPath -Append -Encoding utf8
"START: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $LogPath -Append -Encoding utf8
"Iterations=$Iterations DelaySeconds=$DelaySeconds" | Out-File -FilePath $LogPath -Append -Encoding utf8
"==================================================" | Out-File -FilePath $LogPath -Append -Encoding utf8

for ($i = 1; $i -le $Iterations; $i++) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $msg = "[$timestamp] Snapshot $i / $Iterations"
    Write-Host $msg
    $msg | Out-File -FilePath $LogPath -Append -Encoding utf8

    try {
        $output = & $pythonExe -m $moduleName 2>&1
        $output | Out-File -FilePath $LogPath -Append -Encoding utf8

        if ($LASTEXITCODE -ne 0) {
            $err = "[$timestamp] ERROR: collector zwrócił kod $LASTEXITCODE"
            Write-Host $err -ForegroundColor Red
            $err | Out-File -FilePath $LogPath -Append -Encoding utf8
        }
    }
    catch {
        $err = "[$timestamp] EXCEPTION: $($_.Exception.Message)"
        Write-Host $err -ForegroundColor Red
        $err | Out-File -FilePath $LogPath -Append -Encoding utf8
    }

    if ($i -lt $Iterations) {
        Start-Sleep -Seconds $DelaySeconds
    }
}

"END: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $LogPath -Append -Encoding utf8
Write-Host "Zbieranie zakończone. Log: $LogPath" -ForegroundColor Green