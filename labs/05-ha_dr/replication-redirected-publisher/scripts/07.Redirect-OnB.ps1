param([Parameter(Mandatory)][hashtable]$P)
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\06_redirect_on_B.sql' | Tee-Object -Variable sqlfile | Out-Null
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.SubscriberB -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
