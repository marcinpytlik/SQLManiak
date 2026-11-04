#requires -Version 7.0
[CmdletBinding()]
param(
 [ValidateRange(4,10000)][int]$Trials=280,
 [int]$Seed=20261104,
 [int[]]$Levels=@(200,250,300,350,400,450,500),
 [ValidateSet('both','sync','async')][string]$Mode='both',
 [ValidateRange(1,10000)][int]$MaxPool=550,
 [string]$Prefix='diagnostic'
)
$ErrorActionPreference='Stop'
if(-not $env:SQLCLIENT_BENCH_CS){throw 'Set SQLCLIENT_BENCH_CS first.'}
if($Levels.Count -eq 0 -or $Levels | Where-Object {$_ -lt 1 -or $_ -gt 1000}){throw 'Levels must be 1..1000'}
if($MaxPool -lt ($Levels | Measure-Object -Maximum).Maximum){throw 'MaxPool too small.'}
$modes = if($Mode -eq 'both'){@('async','sync')}else{@($Mode)}
$cells = @(
 foreach($pool in @('v1','v2')){
  foreach($m in $modes){
   foreach($n in $Levels){[pscustomobject]@{pool=$pool;mode=$m;concurrency=[int]$n}}
  }
 }
)
if($Trials -lt $cells.Count){throw "Trials must be at least $($cells.Count)"}
$random=[Random]::new($Seed)
$plan=[Collections.Generic.List[object]]::new()
for($i=0;$i -lt $Trials;$i++){
 $c=$cells[$i % $cells.Count]
 $plan.Add([pscustomobject]@{order=$i+1;pool=$c.pool;mode=$c.mode;concurrency=$c.concurrency})
}
for($i=$plan.Count-1;$i -gt 0;$i--){
 $j=$random.Next($i+1);$tmp=$plan[$i];$plan[$i]=$plan[$j];$plan[$j]=$tmp
}
$root=$PSScriptRoot
$run=Join-Path $root ('results/'+$Prefix+'-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+"-seed$Seed")
New-Item -ItemType Directory -Force -Path $run | Out-Null
$plan | Export-Csv (Join-Path $run 'random-plan.csv') -NoTypeInformation -Encoding utf8
dotnet build (Join-Path $root 'SQLManiak.SqlClientPoolBenchmark.csproj') -c Release
if($LASTEXITCODE -ne 0){throw 'Build failed'}
$dll=Join-Path $root 'bin/Release/net10.0/SQLManiak.SqlClientPoolBenchmark.dll'
$rows=[Collections.Generic.List[object]]::new()
foreach($c in $plan){
 $temp=Join-Path $run 'temp'
 New-Item -ItemType Directory -Force -Path $temp | Out-Null
 $output=& dotnet $dll --pool $c.pool --mode $c.mode --concurrency "$($c.concurrency)" --repetitions 1 --max-pool "$MaxPool" --output $temp 2>&1
 $exit=$LASTEXITCODE
 $csv=@(Get-ChildItem $temp -Filter 'raw-*.csv' -File)
 if($csv.Count -ne 1){$output | Out-Host;throw "Trial $($c.order): missing CSV, exit=$exit"}
 $v=Import-Csv $csv[0].FullName | Select-Object -First 1
 $r=[pscustomobject]@{
  order=$c.order;pool=$v.pool;mode=$v.mode;concurrency=[int]$v.concurrency
  total_ms=$v.total_ms;open_p50_ms=$v.open_p50_ms;open_p95_ms=$v.open_p95_ms
  open_max_ms=$v.open_max_ms;succeeded=[int]$v.succeeded;failed=[int]$v.failed
  process_exit=$exit;worker_setup_ms=$v.worker_setup_ms;process_cpu_ms=$v.process_cpu_ms
  peak_threads=$v.peak_threads;peak_threadpool_pending=$v.peak_threadpool_pending
  min_threadpool_available=$v.min_threadpool_available;gc0=$v.gc0;gc1=$v.gc1
  gc2=$v.gc2;allocated_bytes=$v.allocated_bytes
 }
 $rows.Add($r)
 $r | Export-Csv -Path (Join-Path $run 'all-trials.csv') -Append -NoTypeInformation -Encoding utf8
 Remove-Item $csv[0].FullName -Force
 if(($c.order % 10) -eq 0){Write-Host "$($c.order)/$Trials $($c.pool)/$($c.mode) N=$($c.concurrency) total=$($v.total_ms) failed=$($v.failed)"}
}
$culture=[Globalization.CultureInfo]::InvariantCulture
$summary=@(
 foreach($g in ($rows | Group-Object pool,mode,concurrency)){
  $valid=@($g.Group | Where-Object {$_.failed -eq 0 -and $_.process_exit -eq 0} |
   ForEach-Object {[double]::Parse($_.total_ms,$culture)} | Sort-Object)
  if(-not $valid.Count){continue}
  $first=$g.Group[0]
  [pscustomobject]@{pool=$first.pool;mode=$first.mode;concurrency=$first.concurrency;
   valid=$valid.Count;mean_ms=[math]::Round(($valid | Measure-Object -Average).Average,3);
   median_ms=$valid[[int][math]::Floor(($valid.Count-1)*.5)];
   p95_ms=$valid[[int][math]::Ceiling(($valid.Count-1)*.95)];
   min_ms=$valid[0];max_ms=$valid[-1]}
 }
)
$summary | Sort-Object mode,concurrency,pool | Export-Csv (Join-Path $run 'summary.csv') -NoTypeInformation
$comparison=@(
 foreach($a in ($summary | Where-Object pool -eq 'v1')){
  $b=$summary | Where-Object {$_.pool -eq 'v2' -and $_.mode -eq $a.mode -and $_.concurrency -eq $a.concurrency} | Select-Object -First 1
  if($b -and $b.mean_ms -gt 0){[pscustomobject]@{mode=$a.mode;concurrency=$a.concurrency;
   v1_ms=$a.mean_ms;v2_ms=$b.mean_ms;speedup=[math]::Round($a.mean_ms/$b.mean_ms,3);
   v1_valid=$a.valid;v2_valid=$b.valid}}
 }
)
$comparison | Sort-Object mode,concurrency | Export-Csv (Join-Path $run 'comparison.csv') -NoTypeInformation
$comparison | Sort-Object mode,concurrency | Format-Table -AutoSize
Write-Host "Results: $run"
