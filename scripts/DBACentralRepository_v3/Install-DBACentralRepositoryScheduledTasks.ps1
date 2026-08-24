[CmdletBinding()]
param(
    [string]$ScriptRoot = $PSScriptRoot,

    [string]$RepositoryServerInstance = 'localhost',

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [long]$TableUsageTargetId = 1,

    [int]$BackupHistoryDays = 35,

    [string]$LogRoot = 'C:\DBACentralRepository\Logs',

    [string]$TaskPath = '\DBACentralRepository\',

    [string]$TaskUser = "$env:USERDOMAIN\$env:USERNAME",

    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Constants
# -----------------------------------------------------------------------------

$wrapperScript = Join-Path $ScriptRoot 'Invoke-DBACentralRepositoryCollector.ps1'

$taskNames = @(
    'DBACR - Performance Collector',
    'DBACR - Table Usage Collector',
    'DBACR - Backup Collector',
    'DBACR - Inventory Collector',
    'DBACR - Database Schema Collector'
)

$requiredFiles = @(
    $wrapperScript,
    (Join-Path $ScriptRoot 'Collect-DatabasePerformance.ps1'),
    (Join-Path $ScriptRoot 'Collect-TableUsage.ps1'),
    (Join-Path $ScriptRoot 'Collect-BackupHistory.ps1'),
    (Join-Path $ScriptRoot 'Collect-DBACentralRepository.ps1'),
    (Join-Path $ScriptRoot 'Collect-DatabaseSchema.ps1')
)

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

foreach ($file in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $file)) {
        throw "Required file not found: $file"
    }
}

if (-not (Test-Path -LiteralPath $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
}

# -----------------------------------------------------------------------------
# Uninstall
# -----------------------------------------------------------------------------

if ($Uninstall) {

    foreach ($taskName in $taskNames) {

        $existingTask = Get-ScheduledTask `
            -TaskPath $TaskPath `
            -TaskName $taskName `
            -ErrorAction SilentlyContinue

        if ($null -ne $existingTask) {

            Unregister-ScheduledTask `
                -TaskPath $TaskPath `
                -TaskName $taskName `
                -Confirm:$false

            Write-Host "Removed: $TaskPath$taskName"
        }
    }

    Write-Host ''
    Write-Host 'DBACentralRepository Scheduled Tasks removed.'

    return
}

# -----------------------------------------------------------------------------
# Credentials
# -----------------------------------------------------------------------------

Write-Host ''
Write-Host 'Tasks will run whether the user is logged on or not.'
Write-Host "Enter credentials for: $TaskUser"
Write-Host ''

$credential = Get-Credential `
    -UserName $TaskUser `
    -Message 'Credentials for DBACentralRepository Scheduled Tasks'

$plainPassword = $credential.GetNetworkCredential().Password
$TaskUser = $credential.UserName

# -----------------------------------------------------------------------------
# Scheduled Task common settings
# -----------------------------------------------------------------------------

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 6)

function New-DBACRAction {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            'Performance',
            'TableUsage',
            'Backup',
            'Inventory',
            'DatabaseSchema'
        )]
        [string]$Collector
    )

    $arguments = @(
        '-NoLogo'
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        ('"{0}"' -f $wrapperScript)
        '-Collector'
        $Collector
        '-ScriptRoot'
        ('"{0}"' -f $ScriptRoot)
        '-RepositoryServerInstance'
        ('"{0}"' -f $RepositoryServerInstance)
        '-RepositoryDatabase'
        ('"{0}"' -f $RepositoryDatabase)
        '-TableUsageTargetId'
        $TableUsageTargetId
        '-BackupHistoryDays'
        $BackupHistoryDays
        '-LogRoot'
        ('"{0}"' -f $LogRoot)
    )

    New-ScheduledTaskAction `
        -Execute 'pwsh.exe' `
        -Argument ($arguments -join ' ')
}

function Register-DBACRTask {
    param(
        [Parameter(Mandatory)]
        [string]$TaskName,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Performance',
            'TableUsage',
            'Backup',
            'Inventory',
            'DatabaseSchema'
        )]
        [string]$Collector,

        [Parameter(Mandatory)]
        $Trigger,

        [Parameter(Mandatory)]
        [string]$Description
    )

    $action = New-DBACRAction -Collector $Collector

    $existingTask = Get-ScheduledTask `
        -TaskPath $TaskPath `
        -TaskName $TaskName `
        -ErrorAction SilentlyContinue

    if ($null -ne $existingTask) {

        Unregister-ScheduledTask `
            -TaskPath $TaskPath `
            -TaskName $TaskName `
            -Confirm:$false
    }

    Register-ScheduledTask `
        -TaskPath $TaskPath `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $Trigger `
        -Settings $settings `
        -Description $Description `
        -User $TaskUser `
        -Password $plainPassword `
        -RunLevel Highest `
        -Force | Out-Null

    Write-Host "Registered: $TaskPath$TaskName"
}

# -----------------------------------------------------------------------------
# Triggers
#
# Using long-running repetition triggers because this is the same mechanism
# already used by the existing DBACentralRepository scheduled tasks.
# -----------------------------------------------------------------------------

$repeatStart = (Get-Date).AddMinutes(2)

$performanceTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At $repeatStart `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$tableUsageTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At $repeatStart.AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$backupTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At $repeatStart.AddMinutes(2) `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$inventoryTrigger = New-ScheduledTaskTrigger `
    -Daily `
    -At '01:00'

$schemaTrigger = New-ScheduledTaskTrigger `
    -Daily `
    -At '02:00'

# -----------------------------------------------------------------------------
# Register tasks
# -----------------------------------------------------------------------------

Register-DBACRTask `
    -TaskName 'DBACR - Performance Collector' `
    -Collector 'Performance' `
    -Trigger $performanceTrigger `
    -Description 'Collects DBACentralRepository database performance every 5 minutes.'

Register-DBACRTask `
    -TaskName 'DBACR - Table Usage Collector' `
    -Collector 'TableUsage' `
    -Trigger $tableUsageTrigger `
    -Description 'Collects DBACentralRepository table usage every 15 minutes.'

Register-DBACRTask `
    -TaskName 'DBACR - Backup Collector' `
    -Collector 'Backup' `
    -Trigger $backupTrigger `
    -Description 'Collects SQL Server backup history every 15 minutes.'

Register-DBACRTask `
    -TaskName 'DBACR - Inventory Collector' `
    -Collector 'Inventory' `
    -Trigger $inventoryTrigger `
    -Description 'Collects DBACentralRepository inventory once per day.'

Register-DBACRTask `
    -TaskName 'DBACR - Database Schema Collector' `
    -Collector 'DatabaseSchema' `
    -Trigger $schemaTrigger `
    -Description 'Collects database schema metadata once per day.'

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

Write-Host ''
Write-Host 'DBACentralRepository Scheduled Tasks installed.'
Write-Host ''
Write-Host "Task folder : $TaskPath"
Write-Host "Script root : $ScriptRoot"
Write-Host "Log root    : $LogRoot"
Write-Host ''
Write-Host 'Schedules:'
Write-Host '  Performance     every 5 minutes'
Write-Host '  Table Usage     every 15 minutes'
Write-Host '  Backup          every 15 minutes'
Write-Host '  Inventory       daily at 01:00'
Write-Host '  Database Schema daily at 02:00'
Write-Host ''
Write-Host 'Verification:'
Write-Host "  Get-ScheduledTask -TaskPath '$TaskPath' | Select-Object TaskName,State"
Write-Host ''
Write-Host 'Manual tests:'
Write-Host "  Start-ScheduledTask -TaskPath '$TaskPath' -TaskName 'DBACR - Performance Collector'"
Write-Host "  Start-ScheduledTask -TaskPath '$TaskPath' -TaskName 'DBACR - Backup Collector'"