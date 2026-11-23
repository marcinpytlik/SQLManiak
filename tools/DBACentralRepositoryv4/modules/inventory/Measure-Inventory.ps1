#requires -Version 7.0
<#
.SYNOPSIS
 Benchmark read-only inventory on selected instances. Does not persist snapshots.
.EXAMPLE
 ./modules/inventory/Measure-Inventory.ps1 -ConfigPath ./config/servers.local.json -Repetitions 3
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ConfigPath,
 [ValidateRange(1,20)][int]$Repetitions=3,
 [System.Management.Automation.PSCredential]$SourceCredential,
 [string]$CsvPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$configFile=(Resolve-Path -LiteralPath $ConfigPath).Path
$cfg=Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
if(@($cfg.sourceServers).Count -lt 1) { throw 'No sourceServers configured.' }
$results=[System.Collections.Generic.List[object]]::new()
$collector=Join-Path $PSScriptRoot 'Collect-DBAInventory.ps1'
for($i=1; $i -le $Repetitions; $i++) {
 $stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
 $arguments=@{ConfigPath=$configFile}
 if($null -ne $SourceCredential) { $arguments['SourceCredential']=$SourceCredential }
 $global:LASTEXITCODE=0
 $messages=@(& $collector @arguments 2>&1)
 $stopwatch.Stop()
 $failed=@($messages | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
 $collectorFailed=($global:LASTEXITCODE -ne 0)
 # Collector writes ordinary progress to host. Capture duration independently;
 # do not treat its global LASTEXITCODE as a reliable per-run indicator.
 $results.Add([pscustomobject]@{
  Run=$i
  SourceCount=@($cfg.sourceServers).Count
  DurationMs=[math]::Round($stopwatch.Elapsed.TotalMilliseconds,2)
  CapturedErrors=$failed.Count
  CompletedUtc=[datetime]::UtcNow.ToString('o')
 })
 Write-Host "Iteration $i/$Repetitions : $([math]::Round($stopwatch.Elapsed.TotalSeconds,2)) s, PowerShell errors=$($failed.Count)"
 if($failed.Count -gt 0 -or $collectorFailed) { throw "Read-only benchmark interrupted by PowerShell errors on iteration $i." }
}
$results | Format-Table -AutoSize
if($CsvPath) {
 $results | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding utf8
 Write-Host "CSV: $CsvPath"
}
Write-Host 'Read-only benchmark finished. No snapshots written.'
