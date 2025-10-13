param([Parameter(Mandatory)][hashtable]$P)
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\07_validate_on_C.sql' | Tee-Object -Variable sqlfile | Out-Null
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
