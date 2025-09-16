# PowerShell: cicha deinstalacja SQL Server (bez instalatora)

Poniżej skrypt, który:
- wykrywa zainstalowane instancje z rejestru,
- znajduje **Setup.exe** z *Setup Bootstrap*,
- odinstalowuje całą instancję (wszystkie funkcje) w trybie **quiet**,
- opcjonalnie usuwa współdzielone składniki (Client Connectivity / SDK / Tools\*),
- ma `-WhatIf` (próba „na sucho”),
- loguje przebieg do pliku.

> \* SSMS (SQL Server Management Studio) od 2016+ to osobny instalator – dezinstalujesz go zwykle przez „Aplikacje i funkcje”.

---

## Skrypt: `Uninstall-SqlInstance.ps1`

```powershell
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [string]$InstanceName,              # np. MSSQLSERVER albo SQL2022DEV

    [switch]$RemoveShared,              # usuń współdzielone komponenty (Conn,BC,SDK,Tools*)
    [string]$LogPath = "C:\Temp\SqlUninstall",
    [switch]$VerboseLog
)

function Get-SqlInstances {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Microsoft SQL Server\Instance Names\SQL'
    )
    $result = @()

    foreach ($p in $paths) {
        if (Test-Path $p) {
            Get-ItemProperty $p | ForEach-Object {
                $_.PSObject.Properties |
                    Where-Object { $_.MemberType -eq 'NoteProperty' } |
                    ForEach-Object {
                        [pscustomobject]@{
                            InstanceName = $_.Name
                            InstanceId   = $_.Value  # np. MSSQL16.MSSQLSERVER
                            Hive         = $p
                        }
                    }
            }
        }
    }
    $result | Sort-Object InstanceName -Unique
}

function Find-SetupExe {
    # Szukamy najwyższej wersji Setup.exe w standardowych ścieżkach Bootstrap
    $candidates = @(Get-ChildItem -Path "C:\Program Files\Microsoft SQL Server" -Filter Setup.exe -Recurse -ErrorAction SilentlyContinue),
                  @(Get-ChildItem -Path "C:\Program Files (x86)\Microsoft SQL Server" -Filter Setup.exe -Recurse -ErrorAction SilentlyContinue)

    $candidates = $candidates | Where-Object {
        $_.FullName -match '\\Setup Bootstrap\\' -and $_.Name -eq 'Setup.exe'
    }

    if (-not $candidates) { return $null }

    # wybieramy najwyższą wersję pliku
    $best = $candidates | Sort-Object { $_.VersionInfo.FileVersionRaw } -Descending | Select-Object -First 1
    return $best.FullName
}

function Ensure-LogFolder {
    if (-not (Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
}

Write-Host "==> Wykrywanie instancji..." -ForegroundColor Cyan
$instances = Get-SqlInstances
if (-not $instances) {
    Write-Error "Nie znaleziono żadnych instancji SQL w rejestrze."
    exit 1
}

$target = $instances | Where-Object { $_.InstanceName -ieq $InstanceName }
if (-not $target) {
    Write-Error "Nie znaleziono instancji '$InstanceName'. Dostępne: $($instances.InstanceName -join ', ')"
    exit 1
}

$instanceId = $target.InstanceId   # np. MSSQL16.MSSQLSERVER

Write-Host ("Znaleziono: InstanceName={0}, InstanceId={1}" -f $InstanceName,$instanceId) -ForegroundColor Green

$setup = Find-SetupExe
if (-not $setup) {
    Write-Error "Nie znaleziono Setup.exe w folderach Setup Bootstrap. Sprawdź, czy SQL był zainstalowany poprawnie."
    exit 1
}

Write-Host "Setup.exe: $setup" -ForegroundColor Yellow
Ensure-LogFolder

# Przygotuj parametry deinstalacji instancji
$logFile = Join-Path $LogPath ("uninstall_{0}_{1:yyyyMMdd_HHmmss}.log" -f $InstanceName,(Get-Date))

# Uwaga: /ACTION=Remove; brak /FEATURES => usuwa wszystkie komponenty danej instancji
$commonArgs = @(
    '/Action=Remove',
    "/INSTANCENAME=$InstanceName",
    "/INSTANCEID=$instanceId",
    '/Q',
    '/IACCEPTSQLSERVERLICENSETERMS',
    "/INDICATEPROGRESS",
    "/SkipRules=RebootRequiredCheck"
)

if ($VerboseLog) {
    $commonArgs += "/ENU"
    $commonArgs += "/ERRORREPORTING=1"
}

$commonArgs += "/SQLSYSADMINACCOUNTS=""$env:USERNAME"""  # nie szkodzi, ale bywa pomocne
$commonArgs += "/FLUSHCACHE=1"
$commonArgs += "/x86=false"

# Dodatkowy OUT log – przekierowanie
$startInfo = @{
    FilePath = $setup
    ArgumentList = $commonArgs
    Wait = $true
    PassThru = $true
    RedirectStandardOutput = $logFile
    RedirectStandardError  = $logFile
}

Write-Host "==> Zatrzymywanie usług SQL dla instancji..." -ForegroundColor Cyan
$svcNames = @(
    "MSSQL`$$InstanceName",
    "SQLAgent`$$InstanceName",
    "SQLBrowser",
    "MSSQLServerOLAPService",         # jeśli AS
    "MSOLAP$InstanceName",
    "ReportServer`$$InstanceName",
    "SQLWriter",                      # VSS writer
    "MSSQLFDLauncher`$$InstanceName"  # Full-Text
) | Select-Object -Unique

foreach ($s in $svcNames) {
    try {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Stopped') {
            Write-Host "Stop-Service $s" -ForegroundColor DarkGray
            if ($PSCmdlet.ShouldProcess($s, "Stop-Service")) {
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                $svc.WaitForStatus('Stopped','00:00:20')
            }
        }
    } catch { }
}

Write-Host "==> Deinstalacja instancji '$InstanceName'..." -ForegroundColor Cyan
Write-Host "   Log: $logFile" -ForegroundColor DarkGray

if ($PSCmdlet.ShouldProcess("SQL Instance $InstanceName", "Remove via Setup.exe")) {
    $p = Start-Process @startInfo
    if ($p.ExitCode -ne 0) {
        Write-Warning "Setup.exe zwrócił ExitCode=$($p.ExitCode). Sprawdź log: $logFile"
    } else {
        Write-Host "✔ Instancja odinstalowana (ExitCode 0)."
    }
}

# Opcjonalnie: usunięcie współdzielonych składników
if ($RemoveShared.IsPresent) {
    Write-Host "==> Usuwanie współdzielonych komponentów (Conn,BC,SDK,Tools)..." -ForegroundColor Cyan

    # Uwaga: lista FEATURES zależy od wersji; te zwykle działają dla 2016–2022.
    $sharedFeatures = "CONN,BC,SDK,Tools"
    $logFile2 = Join-Path $LogPath ("uninstall_shared_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

    $args2 = @(
        '/Action=Remove',
        "/FEATURES=$sharedFeatures",
        '/Q',
        '/IACCEPTSQLSERVERLICENSETERMS',
        '/INDICATEPROGRESS'
    )

    $startInfo2 = @{
        FilePath = $setup
        ArgumentList = $args2
        Wait = $true
        PassThru = $true
        RedirectStandardOutput = $logFile2
        RedirectStandardError  = $logFile2
    }

    if ($PSCmdlet.ShouldProcess("Shared Features ($sharedFeatures)", "Remove via Setup.exe")) {
        $p2 = Start-Process @startInfo2
        if ($p2.ExitCode -ne 0) {
            Write-Warning "Usuwanie współdzielonych komponentów: ExitCode=$($p2.ExitCode). Log: $logFile2"
        } else {
            Write-Host "✔ Współdzielone komponenty usunięte (ExitCode 0)."
        }
    }

    Write-Host "Pamiętaj: SSMS to osobna aplikacja – odinstaluj w 'Aplikacje i funkcje'."
}

Write-Host "==> Sprzątanie katalogów (opcjonalne, po backupie!)" -ForegroundColor Cyan
$pathsToConsider = @(
    "C:\Program Files\Microsoft SQL Server",
    "C:\Program Files (x86)\Microsoft SQL Server",
    "C:\ProgramData\Microsoft\SQL Server"
)
foreach ($p in $pathsToConsider) {
    if (Test-Path $p) {
        Write-Host "Pozostałości (sprawdź przed usunięciem): $p"
    }
}

Write-Host "Gotowe."
