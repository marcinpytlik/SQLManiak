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
# Query exact task name using native Task Scheduler COM service.
# The ScheduledTasks CIM provider can report an XML error even after
# schtasks.exe /Delete successfully removed the task.
# 0x80070002 means no task with that exact name. Any other HRESULT is fatal.
$scheduler=New-Object -ComObject 'Schedule.Service'
$scheduler.Connect()
$folder=$scheduler.GetFolder('\')
$found=$null
try {
 $found=$folder.GetTask($TaskName)
} catch {
 # PowerShell 7 COM dynamic invocation can surface HRESULT 0x80070002 as
 # System.IO.FileNotFoundException instead of COMException.
 # Compare the HRESULT, not the exception's .NET type or message language.
 $hr=[int64]$_.Exception.HResult
 if($hr -ne -2147024894) {
  $hex='{0:X8}' -f ($hr -band 0xFFFFFFFFL)
  throw "Cannot inspect LAB task via Task Scheduler COM (HRESULT 0x$hex): $($_.Exception.Message)"
 }
}
if($null -ne $found){
 throw "Task already exists: $TaskName. Refusing to overwrite."
}
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
# The preview emits normal scheduler rows that have no TestResult property.
# In StrictMode, Where-Object TestResult -eq 'PASS' throws on those rows.
$passed=@($preflightResult | Where-Object {
 $_.PSObject.Properties.Match('TestResult').Count -gt 0 -and
 $_.TestResult -eq 'PASS'
})
if($passed.Count -ne 1){
 throw 'Identity and DPAPI preflight did not return PASS.'
}
$arguments='-NoLogo -NoProfile -NonInteractive -File "{0}" -ConfigPath "{1}" -Environment LAB -Execute' -f $scriptPath,$configFull
$action=New-ScheduledTaskAction -Execute $pwshPath -Argument $arguments -WorkingDirectory $PSScriptRoot
# Test-only trigger: 5-minute repetition during a 24-hour window.
# Avoid the prior 365-day duration suspected of producing invalid task XML.
# Plan a permanent schedule only after successful registration and manual tests.
$trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(5) -RepetitionInterval (New-TimeSpan -Minutes $SchedulerIntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 1)
$principal=New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings=New-ScheduledTaskSettingsSet -Disable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$definition=New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'LAB ONLY; disabled by default; due-aware DHC using same-Windows-user DPAPI; runs only while signed in.'
Register-ScheduledTask -TaskName $TaskName -TaskPath '\' -InputObject $definition -ErrorAction Stop | Out-Null
# Verify with COM instead of Get-ScheduledTask (CIM provider XML parser
# may fail even when a particular task can be queried by COM).
try {
 $task=$folder.GetTask($TaskName)
 $definitionRegistered=$task.Definition
 $isDisabled=(-not $task.Enabled) -and (-not $definitionRegistered.Settings.Enabled)
 $principalOk=([string]$definitionRegistered.Principal.UserId -eq $identity)
 $interactiveOk=([int]$definitionRegistered.Principal.LogonType -eq 3) # TASK_LOGON_INTERACTIVE_TOKEN
 $overlapOk=([int]$definitionRegistered.Settings.MultipleInstances -eq 2) # TASK_INSTANCES_IGNORE_NEW
 if(-not ($isDisabled -and $principalOk -and $interactiveOk -and $overlapOk)){
  throw "Registered LAB task failed read-only COM verification; inspect before enabling."
 }
} catch {
 throw "Task was submitted for registration, but Task Scheduler COM verification failed. Do NOT enable. $($_.Exception.Message)"
}
[pscustomobject]@{
 TaskName=$TaskName
 TaskPath='\'
 State='Disabled'
 Principal=[string]$definitionRegistered.Principal.UserId
 LogonType='InteractiveToken'
 Program=[string]$definitionRegistered.Actions.Item(1).Path
 RepeatEveryMinutes=$SchedulerIntervalMinutes
 OverlapPolicy='IgnoreNew'
 DpapiPreflight='PASS'
 TaskStarted=$false
 RequiresSignedInUser=$true
}
Write-Host 'Test 46B: PASS — task created DISABLED; no automatic collection has been enabled.' -ForegroundColor Green
