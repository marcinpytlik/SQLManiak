#requires -Version 7.0
[CmdletBinding()]
param(
 [int[]]$Levels=@(300,400,500),
 [ValidateRange(1,30)][int]$Repetitions=5,
 [ValidateRange(1,1000)][int]$MaxPool=550,
 [int]$Seed=20261104,
 [ValidateRange(5,100)][int]$Top=30
)
$ErrorActionPreference='Stop'
if(-not $env:SQLCLIENT_BENCH_CS){throw 'Set SQLCLIENT_BENCH_CS first'}
if(-not (Get-Command dotnet-trace -ErrorAction SilentlyContinue)){throw 'Install dotnet-trace: dotnet tool install --global dotnet-trace'}
if($MaxPool -lt ($Levels | Measure-Object -Maximum).Maximum){throw 'MaxPool too small'}
$root=$PSScriptRoot
dotnet build (Join-Path $root 'SQLManiak.SqlClientPoolBenchmark.csproj') -c Release
if($LASTEXITCODE -ne 0){throw 'Build failed'}
$dll=Join-Path $root 'bin/Release/net10.0/SQLManiak.SqlClientPoolBenchmark.dll'
$run=Join-Path $root ('results/profile-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+"-seed$Seed")
New-Item -ItemType Directory -Force $run | Out-Null
$random=[Random]::new($Seed)
$plan=@(foreach($n in $Levels){foreach($pool in @('v1','v2')){[pscustomobject]@{pool=$pool;n=$n;key=$random.NextDouble()}}} | Sort-Object key)
$measurements=[Collections.Generic.List[object]]::new()
foreach($c in $plan){
 $tag="$($c.pool)-sync-N$($c.n)"
 $case=Join-Path $run $tag
 New-Item -ItemType Directory -Force $case | Out-Null
 $trace=Join-Path $case "$tag.nettrace"
 Write-Host "Profiling $tag"
 & dotnet-trace collect --profile 'dotnet-sampled-thread-time,dotnet-common' --output $trace -- dotnet $dll --pool $c.pool --mode sync --concurrency "$($c.n)" --repetitions "$Repetitions" --max-pool "$MaxPool" --output $case
 if($LASTEXITCODE -ne 0){throw "Tracing failed for $tag"}
 $raw=@(Get-ChildItem $case -Filter 'raw-*.csv')
 if($raw.Count -ne 1){throw "Expected one raw CSV for $tag"}
 Import-Csv $raw[0].FullName | ForEach-Object {$measurements.Add($_)}
 & dotnet-trace report $trace topN --number "$Top" --inclusive | Out-File (Join-Path $case 'top-inclusive.txt')
 & dotnet-trace report $trace topN --number "$Top" | Out-File (Join-Path $case 'top-exclusive.txt')
}
$measurements | Export-Csv (Join-Path $run 'measurements.csv') -NoTypeInformation
$summary=@(
 foreach($g in ($measurements | Group-Object pool,concurrency)){
  $valid=@($g.Group | Where-Object {[int]$_.failed -eq 0})
  if($valid.Count -eq 0){continue}
  [pscustomobject]@{pool=$valid[0].pool;concurrency=$valid[0].concurrency;valid=$valid.Count;
    mean_ms=[math]::Round(($valid | Measure-Object total_ms -Average).Average,2);
    mean_cpu_ms=[math]::Round(($valid | Measure-Object process_cpu_ms -Average).Average,2)}
 }
)
$summary | Export-Csv (Join-Path $run 'summary.csv') -NoTypeInformation
$summary | Format-Table
Write-Host "Results: $run"
Write-Warning 'Trace files may include environmental details. Review before sharing.'
