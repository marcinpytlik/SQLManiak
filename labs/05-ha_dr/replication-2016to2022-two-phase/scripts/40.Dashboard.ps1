param([Parameter(Mandatory)][string]$ParamsPath)
$P = Import-PowerShellDataFile $ParamsPath
. "$PSScriptRoot\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile (Join-Path $PSScriptRoot '..\sql_common\12_dashboard_dmv.sql')
