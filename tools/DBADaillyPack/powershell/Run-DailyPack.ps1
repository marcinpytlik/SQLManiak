<#
Run DBA Daily Pack via sqlcmd.
Edit $ServerInstance and auth (Windows/SQL).
#>

param(
  [string]$ServerInstance = "localhost",
  [string]$Database = "master",
  [string]$OutDir = ".\out"
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Run-SqlFile($file, $outFile) {
  Write-Host "Running $file -> $outFile"
  sqlcmd -S $ServerInstance -d $Database -E -i $file -W -w 4000 -o $outFile
}

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $here "..")

$files = @(
  "sql\01_Backup_Compliance.sql",
  "sql\02_Agent_Jobs_Health.sql",
  "sql\03_Tempdb_Health.sql",
  "sql\04_Health_Signals.sql",
  "sql\06_IO_Latency_And_Volumes.sql",
  "sql\07_Blocking_And_LongRunning.sql",
  "sql\08_Errorlog_Scan.sql"
)

foreach ($f in $files) {
  $src = Join-Path $root $f
  $name = [IO.Path]::GetFileNameWithoutExtension($src)
  $dst = Join-Path $OutDir ($name + ".txt")
  Run-SqlFile $src $dst
}

Write-Host "Done. Outputs in $OutDir"
