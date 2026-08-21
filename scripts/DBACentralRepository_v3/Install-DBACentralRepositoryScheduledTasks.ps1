[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$TaskFolder = '\DBACentralRepository\',

    [string]$ScriptRoot = 'C:\Users\blad\Documents\GitHub\SQLManiak\scripts\DBACentralRepository_v3',

    [string]$RepositoryServerInstance = 'localhost',

    [string]$RepositoryDatabase = 'DBACentralRepository',

    [string]$ServerListPath = 'Servers.csv',

    [long]$TableUsageTargetId = 1,

    [string]$LogRoot = 'C:\DBACentralRepository\Logs',

    [string]$PowerShellExe = 'pwsh.exe',

    [string]$TaskUser = "$env:USERDOMAIN\$env:USERNAME",

    [switch]$UseCurrentInteractiveUser,

    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$wrapperPath = Join-Path $ScriptRoot 'Invoke-DBACentralRepositoryCollector.ps1'

function Ensure-TaskFolder {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Path -eq '\') {
        return
    }

    $normalized = $Path.Trim('\')

    $service = New-Object -ComObject 'Schedule.Service'
    $service.Connect()

    $root = $service.GetFolder('\')
    $current = $root

    foreach ($part in ($normalized -split '\\')) {
        if ([string]::IsNullOrWhiteSpace($part)) {
            continue
        }

        try {
            $current = $current.GetFolder($part)
        }
        catch {
            $current = $current.CreateFolder($part)
        }
    }
}

if ($Uninstall) {
    $taskNames = @(
        'DBACR - Performance Collector',
        'DBACR - Table Usage Collector',
        'DBACR - Inventory Collector',
        'DBACR - Database Schema Collector'
    )

    foreach ($taskName in $taskNames) {
        try {
            if ($PSCmdlet.ShouldProcess("$TaskFolder$taskName", 'Unregister scheduled task')) {
                Unregister-ScheduledTask `
                    -TaskPath $TaskFolder `
                    -TaskName $taskName `
                    -Confirm:$false `
                    -ErrorAction Stop

                Write-Host "Removed: $TaskFolder$taskName"
            }
        }
        catch {
            if ($_.Exception.Message -notmatch 'cannot find|not exist|No MSFT_ScheduledTask') {
                Write-Warning $_.Exception.Message
            }
        }
    }

    return
}

foreach ($required in @(
    $wrapperPath,
    (Join-Path $ScriptRoot 'Collect-DatabasePerformance.ps1'),
    (Join-Path $ScriptRoot 'Collect-TableUsage.ps1'),
    (Join-Path $ScriptRoot 'Collect-DBACentralRepository.ps1'),
    (Join-Path $ScriptRoot 'Collect-DatabaseSchema.ps1')
)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Required file not found: $required"
    }
}

if (-not (Test-Path -LiteralPath $LogRoot)) {
    New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
}

Ensure-TaskFolder -Path $TaskFolder

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 2)

function New-CollectorAction {
    param(
        [Parameter(Mandatory)]
        [string]$Collector
    )

    $args = @(
        '-NoLogo'
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $wrapperPath)
        '-Collector', $Collector
        '-ScriptRoot', ('"{0}"' -f $ScriptRoot)
        '-RepositoryServerInstance', ('"{0}"' -f $RepositoryServerInstance)
        '-RepositoryDatabase', ('"{0}"' -f $RepositoryDatabase)
        '-ServerListPath', ('"{0}"' -f $ServerListPath)
        '-TableUsageTargetId', $TableUsageTargetId
        '-LogRoot', ('"{0}"' -f $LogRoot)
    ) -join ' '

    New-ScheduledTaskAction `
        -Execute $PowerShellExe `
        -Argument $args `
        -WorkingDirectory $ScriptRoot
}

function Register-DBACRTask {
    param(
        [Parameter(Mandatory)][string]$TaskName,
        [Parameter(Mandatory)][string]$Collector,
        [Parameter(Mandatory)]$Trigger,
        [Parameter(Mandatory)][string]$Description,
        [string]$User,
        [string]$Password
    )

    $action = New-CollectorAction -Collector $Collector

    if ($PSCmdlet.ShouldProcess("$TaskFolder$TaskName", 'Register/replace scheduled task')) {

        Unregister-ScheduledTask `
            -TaskPath $TaskFolder `
            -TaskName $TaskName `
            -Confirm:$false `
            -ErrorAction SilentlyContinue

        if ($UseCurrentInteractiveUser) {
            Register-ScheduledTask `
                -TaskPath $TaskFolder `
                -TaskName $TaskName `
                -Action $action `
                -Trigger $Trigger `
                -Settings $settings `
                -Description $Description `
                -User $TaskUser `
                -RunLevel Highest `
                -Force | Out-Null
        }
        else {
            Register-ScheduledTask `
                -TaskPath $TaskFolder `
                -TaskName $TaskName `
                -Action $action `
                -Trigger $Trigger `
                -Settings $settings `
                -Description $Description `
                -User $User `
                -Password $Password `
                -RunLevel Highest `
                -Force | Out-Null
        }

        Write-Host "Registered: $TaskFolder$TaskName"
    }
}

$taskCredential = $null
$plainPassword = $null

if (-not $UseCurrentInteractiveUser) {
    Write-Host ''
    Write-Host 'Tasks will run whether the user is logged on or not.'
    Write-Host "Enter credentials for: $TaskUser"

    $taskCredential = Get-Credential `
        -UserName $TaskUser `
        -Message 'Credentials for DBACentralRepository Scheduled Tasks'

    $TaskUser = $taskCredential.UserName
    $plainPassword = $taskCredential.GetNetworkCredential().Password
}

# --------------------------------------------------------------------
# Repeating triggers.
#
# New-ScheduledTaskTrigger -Daily does not expose a mutable Repetition
# property in all ScheduledTasks module versions. Use the supported
# -Once + -RepetitionInterval/-RepetitionDuration parameter set.
#
# Duration is 10 years. Re-running this installer refreshes it.
# --------------------------------------------------------------------

$repeatStart = (Get-Date).AddMinutes(1)

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

# Daily collectors.
$inventoryTrigger = New-ScheduledTaskTrigger -Daily -At '01:00'
$schemaTrigger    = New-ScheduledTaskTrigger -Daily -At '02:00'

Register-DBACRTask `
    -TaskName 'DBACR - Performance Collector' `
    -Collector 'Performance' `
    -Trigger $performanceTrigger `
    -Description 'Collects DBACentralRepository performance samples every 5 minutes.' `
    -User $TaskUser `
    -Password $plainPassword

Register-DBACRTask `
    -TaskName 'DBACR - Table Usage Collector' `
    -Collector 'TableUsage' `
    -Trigger $tableUsageTrigger `
    -Description 'Collects DBACentralRepository table usage every 15 minutes.' `
    -User $TaskUser `
    -Password $plainPassword

Register-DBACRTask `
    -TaskName 'DBACR - Inventory Collector' `
    -Collector 'Inventory' `
    -Trigger $inventoryTrigger `
    -Description 'Runs the full DBACentralRepository inventory once per day.' `
    -User $TaskUser `
    -Password $plainPassword

Register-DBACRTask `
    -TaskName 'DBACR - Database Schema Collector' `
    -Collector 'DatabaseSchema' `
    -Trigger $schemaTrigger `
    -Description 'Collects database schema metadata once per day.' `
    -User $TaskUser `
    -Password $plainPassword

Write-Host ''
Write-Host 'DBACentralRepository Scheduled Tasks installed.'
Write-Host ''
Write-Host "Task folder : $TaskFolder"
Write-Host "Script root : $ScriptRoot"
Write-Host "Log root    : $LogRoot"
Write-Host ''
Write-Host 'Schedules:'
Write-Host '  Performance     every 5 minutes'
Write-Host '  Table Usage     every 15 minutes'
Write-Host '  Inventory       daily at 01:00'
Write-Host '  Database Schema daily at 02:00'
Write-Host ''
Write-Host 'Verification:'
Write-Host "  Get-ScheduledTask -TaskPath '$TaskFolder' | Select-Object TaskName,State"
Write-Host ''
Write-Host 'Manual test:'
Write-Host "  Start-ScheduledTask -TaskPath '$TaskFolder' -TaskName 'DBACR - Performance Collector'"