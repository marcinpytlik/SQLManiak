#requires -Version 7.2
<#
.SYNOPSIS
  Test 46B read-only verification for an already registered LAB task.
.DESCRIPTION
  Uses Task Scheduler COM and checks principal by SID, not text username.
  Does NOT enable, start, remove or modify the task.
#>
[CmdletBinding()]
param(
 [string]$TaskName='SQLManiak DHC v1.7 LAB',
 [string]$ExpectedComputer='DEWELOPER',
 [string]$ExpectedIdentity='DEWELOPER\blad'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Windows-only test.'}
$actualIdentity=[System.Security.Principal.WindowsIdentity]::GetCurrent()
if($env:COMPUTERNAME -ne $ExpectedComputer -or $actualIdentity.Name -ne $ExpectedIdentity){
 throw 'Unexpected Windows host or identity; refusing LAB verification.'
}
$svc=New-Object -ComObject 'Schedule.Service'
$svc.Connect()
$task=$svc.GetFolder('\').GetTask($TaskName)
$d=$task.Definition
$storedName=[string]$d.Principal.UserId
$storedSid=([System.Security.Principal.NTAccount]::new($storedName)).Translate([System.Security.Principal.SecurityIdentifier]).Value
$expectedSid=$actualIdentity.User.Value
$checks=[ordered]@{
 Disabled=( -not [bool]$task.Enabled -and -not [bool]$d.Settings.Enabled -and [int]$task.State -eq 1 )
 SameIdentity=($storedSid -eq $expectedSid)
 InteractiveToken=([int]$d.Principal.LogonType -eq 3)
 LimitedRunLevel=([int]$d.Principal.RunLevel -eq 0)
 IgnoreNewOverlap=([int]$d.Settings.MultipleInstances -eq 2)
}
[pscustomobject]@{
 TaskName=$task.Name
 State=if($checks.Disabled){'Disabled'}else{'Unexpected'}
 StoredPrincipal=$storedName
 ExpectedPrincipal=$ExpectedIdentity
 PrincipalSidMatches=$checks.SameIdentity
 LogonType=[int]$d.Principal.LogonType
 RunLevel=[int]$d.Principal.RunLevel
 MultipleInstances=[int]$d.Settings.MultipleInstances
 TestResult=if(@($checks.Values | Where-Object { -not $_ }).Count -eq 0){'PASS'}else{'FAIL'}
}
if(@($checks.Values | Where-Object { -not $_ }).Count -gt 0){
 throw ('LAB task verification failed: '+(($checks.Keys | Where-Object { -not $checks[$_] }) -join ', ')+'. Do NOT enable.')
}
Write-Host 'Test 46B: PASS — existing task is disabled and principal SID matches; no changes made.' -ForegroundColor Green
