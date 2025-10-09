param([Parameter(Mandatory)][string]$ParamsPath)
$P = Import-PowerShellDataFile $ParamsPath
. "$PSScriptRoot\..\scripts\Invoke-Tsql.ps1" -Server $P.NewPublisherC -InputFile (Join-Path $PSScriptRoot '..\sql_common\10_alerts_and_operator.sql')
