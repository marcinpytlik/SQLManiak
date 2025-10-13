param([Parameter(Mandatory)][hashtable]$P)
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\05_restore_on_C_keep_replication.sql' | Tee-Object -Variable sqlfile | Out-Null
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
