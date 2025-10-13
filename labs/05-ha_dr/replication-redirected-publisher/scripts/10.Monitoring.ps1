param([Parameter(Mandatory)][hashtable]$P, [ValidateSet('A','C')][string]$On='C')
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\09_monitoring.sql' | Tee-Object -Variable sqlfile | Out-Null
$server = if ($On -eq 'C') { $P.NewPublisherC } else { $P.PublisherA }
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $server -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
