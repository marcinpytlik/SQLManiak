#requires -Version 7.2
<#
.SYNOPSIS
  Test 46B: register a DISABLED Windows Scheduled Task for SQLManiak DHC LAB.
.DESCRIPTION
  Uses interactive-token logon for the CURRENT Windows account only.
  DPAPI credentials must be exported under that same account and machine.
  Does NOT start or enable the task. Does NOT change SQL Server data,
  repository intervals, Docker containers, Agent jobs, or credentials.
  Refuses existing task names and unexpected machine/user.
  InteractiveToken: task will NOT run when the user is signed out.
#>
[CmdletBinding()]
param(
 [string]$TaskName='SQLManiak DHC v1.7 LAB',
 [string]$ConfigPath=(Join-Path $env:LOCALAPPDATA 'SQLManiakDHC-fullleastpriv\scheduler.json'),
 [ValidateRange(1,60)][int]$SchedulerIntervalMinutes=5,
 [string]$ExpectedIdentity='DEWELOPER\blad',
 [string]$ExpectedComputer='DEWELOPER'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Windows Task Scheduler is required.'}
if($env:COMPUTERNAME -ne $ExpectedComputer){
 throw "Expected LAB computer $ExpectedComputer; found $env:COMPUTERNAME."
}
$identity=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name
if($identity -ne $ExpectedIdentity){
 throw "Expected DPAPI identity $ExpectedIdentity; found $identity. No task registered."
}
Import-Module ScheduledTasks -ErrorAction Stop
$existing=Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue
if($null -ne $existing){throw "Task already exists: $TaskName. Refusing to overwrite."}
if(-not(Test-Path -LiteralPath $ConfigPath -PathType Leaf)){
 throw "DPAPI scheduler configuration missing: $ConfigPath"
}
$configFull=[IO.Path]::GetFullPath($ConfigPath)
$scriptPath=Join-Path $PSScriptRoot '17_Invoke-DHC-Scheduled.ps1'
$sourcePath=Join-Path $PSScriptRoot 'SQLManiak_Daily_Health_Check_v1_5_CSV.sql'
if(-not(Test-Path -LiteralPath $scriptPath -PathType Leaf) -or
   -not(Test-Path -LiteralPath $sourcePath -PathType Leaf)){
 throw 'Missing DHC runner or local SQL source script.'
}
$pwshCommand=Get-Command pwsh.exe -CommandType Application -ErrorAction Stop
$pwshPath=$pwshCommand.Source
foreach($path in @($scriptPath,$configFull,$pwshPath)){
 if($path.Contains('"')){throw 'Quotes in an execution path are unsupported.'}
}
# Validate actual DPAPI credentials and read-only SQL repository preview,
# without enabling or invoking a collection.
$preflight=Join-Path $PSScriptRoot '21_Test-SchedulerIdentity.ps1'
$preflightResult=& $preflight -ConfigPath $configFull -Environment LAB -CheckSqlPreview
if(@($preflightResult | Where-Object TestResult -eq 'PASS').Count -ne 1){
 throw 'Identity and DPAPI preflight did not return PASS.'
}
$arguments='-NoLogo -NoProfile -NonInteractive -File "{0}" -ConfigPath "{1}" -Environment LAB -Execute' -f $scriptPath,$configFull
$action=New-ScheduledTaskAction -Execute $pwshPath -Argument $arguments -WorkingDirectory $PSScriptRoot
# Once + repeating for 365 days is explicit and portable. Refresh later if
# a permanent LAB schedule is desired; the task starts DISABLED.
$trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes $SchedulerIntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365)
$principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -Disable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$definition=New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'LAB ONLY; disabled by default; due-aware DHC using same-Windows-user DPAPI; runs only while signed in.'
Register-ScheduledTask -TaskName $TaskName -TaskPath '\' -InputObject $definition -ErrorAction Stop | Out-Null
$task=Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
if($task.State -ne 'Disabled' -or $task.Principal.UserId -ne $identity){
 try {Disable-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop | Out-Null} catch {}
 throw "Task state/principal verification failed. Inspect task: $TaskName"
}
[pscustomobject]@{
 TaskName=$TaskName
 TaskPath='\'
 State=$task.State
 Principal=$task.Principal.UserId
 LogonType=$task.Principal.LogonType
 Program=$task.Actions[0].Execute
 RepeatEveryMinutes=$SchedulerIntervalMinutes
 OverlapPolicy=$task.Settings.MultipleInstances
 DpapiPreflight='PASS'
 TaskStarted=$false
 RequiresSignedInUser=$true
}
Write-Host 'Test 46B: PASS — task created DISABLED; no automatic collection has been enabled.' -ForegroundColor Green
