[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Performance','TableUsage','Inventory','DatabaseSchema','Backup')]
    [string]$Collector,

    [Parameter(Mandatory)]
    [string]$ScriptRoot,

    [Parameter(Mandatory)]
    [string]$RepositoryServerInstance,

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$ServerListPath = 'Servers.csv',

    [long]$TableUsageTargetId = 1,

    [int]$BackupHistoryDays = 35,

    [string]$LogRoot = 'C:\DBACentralRepository\Logs'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = Join-Path $LogRoot ("{0}_{1}.log" -f $Collector, $timestamp)

function Write-RunLog {
    param([string]$Message)
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Message
    $line | Tee-Object -FilePath $logFile -Append
}

try {
    Write-RunLog "START Collector=$Collector"
    Write-RunLog "Host=$env:COMPUTERNAME User=$env:USERDOMAIN\$env:USERNAME"
    Write-RunLog "ScriptRoot=$ScriptRoot Repository=$RepositoryServerInstance/$RepositoryDatabase"

    switch ($Collector) {
        'Performance' {
            $script = Join-Path $ScriptRoot 'Collect-DatabasePerformance.ps1'
            if (-not (Test-Path -LiteralPath $script)) { throw "Missing script: $script" }

            & $script `
                -RepositoryServerInstance $RepositoryServerInstance `
                -RepositoryDatabase $RepositoryDatabase *>&1 |
                Tee-Object -FilePath $logFile -Append
        }

        'TableUsage' {
            $script = Join-Path $ScriptRoot 'Collect-TableUsage.ps1'
            if (-not (Test-Path -LiteralPath $script)) { throw "Missing script: $script" }

            & $script `
                -RepositoryServerInstance $RepositoryServerInstance `
                -RepositoryDatabase $RepositoryDatabase `
                -TableUsageTargetId $TableUsageTargetId *>&1 |
                Tee-Object -FilePath $logFile -Append
        }

        'Inventory' {
            $script = Join-Path $ScriptRoot 'Collect-DBACentralRepository.ps1'
            if (-not (Test-Path -LiteralPath $script)) { throw "Missing script: $script" }

            $servers = if ([System.IO.Path]::IsPathRooted($ServerListPath)) {
                $ServerListPath
            } else {
                Join-Path $ScriptRoot $ServerListPath
            }

            if (-not (Test-Path -LiteralPath $servers)) { throw "Missing server list: $servers" }

            & $script `
                -ServerListPath $servers `
                -RepositoryServerInstance $RepositoryServerInstance `
                -RepositoryDatabase $RepositoryDatabase `
                -CollectionMode Full *>&1 |
                Tee-Object -FilePath $logFile -Append
        }

        'DatabaseSchema' {
            $script = Join-Path $ScriptRoot 'Collect-DatabaseSchema.ps1'
            if (-not (Test-Path -LiteralPath $script)) { throw "Missing script: $script" }

            # Collect-DatabaseSchema.ps1 in this repository is invoked against the
            # central repository and obtains target instances from repository state.
            & $script `
                -RepositoryServerInstance $RepositoryServerInstance `
                -RepositoryDatabase $RepositoryDatabase *>&1 |
                Tee-Object -FilePath $logFile -Append
        }

        'Backup' {
            $script = Join-Path $ScriptRoot 'Collect-BackupHistory.ps1'
            if (-not (Test-Path -LiteralPath $script)) { throw "Missing script: $script" }

            & $script `
                -RepositoryServerInstance $RepositoryServerInstance `
                -RepositoryDatabase $RepositoryDatabase `
                -HistoryDays $BackupHistoryDays *>&1 |
                Tee-Object -FilePath $logFile -Append
        }
    }

    if (-not $?) {
        throw "Collector returned an unsuccessful PowerShell status."
    }

    Write-RunLog "SUCCESS Collector=$Collector"
    exit 0
}
catch {
    Write-RunLog ("ERROR Collector={0}: {1}" -f $Collector, $_.Exception.Message)
    Write-RunLog $_.ScriptStackTrace
    exit 1
}
