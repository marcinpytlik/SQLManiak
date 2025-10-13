param([Parameter(Mandatory)][hashtable]$P, [ValidateSet('A','C')][string]$Where='A')
. "$PSScriptRoot\Resolve-RepoPath.ps1" -RelativePath 'sql\08_start_agents.sql' | Tee-Object -Variable sqlfile | Out-Null
$server = if ($Where -eq 'A') { $P.PublisherA } else { $P.NewPublisherC }
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $server -InputFile $sqlfile -UseSqlAuth:$P.UseSqlAuth -User $P.SqlUser -Password $P.SqlPassword
