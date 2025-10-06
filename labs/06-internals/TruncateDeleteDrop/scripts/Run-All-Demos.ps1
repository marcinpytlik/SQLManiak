Param(
  [string]$ServerInstance = "localhost"
)

Write-Host "Running all demos against $ServerInstance ..." -ForegroundColor Cyan

# Helper to run sqlcmd
function Run-Sql {
  param([string]$Path, [string]$Db = "tempdb")
  Write-Host "==> $Path (DB=$Db)"
  & sqlcmd -S $ServerInstance -E -d $Db -b -i $Path
  if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed for $Path" }
}

# 01 Delete vs Truncate
Run-Sql ".\01_DeleteVsTruncate\01_setup.sql"
Run-Sql ".\01_DeleteVsTruncate\02_delete_demo.sql"
Run-Sql ".\01_DeleteVsTruncate\03_check_ghosts.sql"
Run-Sql ".\01_DeleteVsTruncate\04_truncate_demo.sql"
Run-Sql ".\01_DeleteVsTruncate\99_cleanup.sql"

# 02 Truncate vs Drop
Run-Sql ".\02_TruncateVsDrop\demo.sql"

# 04 Locks & Transactions – only prepare here (interactive steps recommended)
Run-Sql ".\04_LocksTransactions\01_prepare.sql"

# 05 RCSI vs SI – prepare DB
& sqlcmd -S $ServerInstance -E -b -i ".\05_RCSI_vs_SI\01_prep_db.sql"
if ($LASTEXITCODE -ne 0) { throw "prep_db failed" }

Write-Host "All scripted parts executed. For interactive parts, open the respective README.md files." -ForegroundColor Green
