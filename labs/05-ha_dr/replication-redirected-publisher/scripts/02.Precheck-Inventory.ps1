param([Parameter(Mandatory)][hashtable]$P)
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\00_inventory.sql' | Tee-Object -Variable sqlfile | Out-Null
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.PublisherA -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
