param([Parameter(Mandatory)][hashtable]$P)
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql_dist_migration\10_prechecks_undistributed_cmds.sql' | Tee-Object -Variable s10 | Out-Null
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql_dist_migration\11_configure_distribution_on_C.sql' | Tee-Object -Variable s11 | Out-Null
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql_dist_migration\12_snapshot_logreader_jobs_on_C.sql' | Tee-Object -Variable s12 | Out-Null
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql_dist_migration\13_recreate_push_agents_on_C.sql' | Tee-Object -Variable s13 | Out-Null
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql_dist_migration\15_validation_after_move.sql' | Tee-Object -Variable s15 | Out-Null
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql_dist_migration\14_cleanup_distribution_on_A.sql' | Tee-Object -Variable s14 | Out-Null

# 1) Precheck/Stop na A
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -InputFile $s10 -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

# 2) Konfiguracja dystrybucji na C
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile $s11 -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

# 3) Joby na C (Snapshot + ewentualne ustawienia LogReader)
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile $s12 -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

# 4) Dla PUSH: odtwórz Distribution Agent na C
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile $s13 -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

# 5) Walidacja
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile $s15 -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword

# 6) Sprzątanie na A
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -InputFile $s14 -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
