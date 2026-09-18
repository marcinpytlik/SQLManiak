param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl,
    [string]$TemplatePath = (Join-Path $PSScriptRoot "..\templates\SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml"),
    [string]$ApiToken = $env:ZABBIX_API_TOKEN,
    [switch]$DeleteMissing
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if ([string]::IsNullOrWhiteSpace($ApiToken)) { throw "Brak tokena API. Przekaż -ApiToken albo ustaw ZABBIX_API_TOKEN." }
if (-not (Test-Path $TemplatePath)) { throw "Nie znaleziono pliku: $TemplatePath" }

function Invoke-ZabbixApi {
    param([string]$Method, [object]$Params)
    $payload = @{ jsonrpc = "2.0"; method = $Method; params = $Params; id = 1 } | ConvertTo-Json -Depth 100
    $headers = @{ Authorization = "Bearer $ApiToken" }
    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -Headers $headers -ContentType "application/json-rpc" -Body $payload
    if ($null -ne $response.error) {
        $details = $response.error | ConvertTo-Json -Depth 20 -Compress
        throw "Błąd Zabbix API dla $Method : $details"
    }
    return $response.result
}

function Get-ImportRules {
    param([bool]$UseDeleteMissing)
    $rules = @{}
    $rules.template_groups = @{ createMissing = $true; updateExisting = $true }
    $rules.templates = @{ createMissing = $true; updateExisting = $true }
    foreach ($name in @("items","discoveryRules","triggers","graphs","httptests","templateDashboards","valueMaps")) {
        $rules[$name] = @{ createMissing = $true; updateExisting = $true; deleteMissing = $UseDeleteMissing }
    }
    $rules.templateLinkage = @{ createMissing = $true; deleteMissing = $UseDeleteMissing }
    return $rules
}

$source = [System.IO.File]::ReadAllText([System.IO.Path]::GetFullPath($TemplatePath))
$rules = Get-ImportRules -UseDeleteMissing:$DeleteMissing.IsPresent
$result = Invoke-ZabbixApi -Method "configuration.importcompare" -Params @{ format = "yaml"; source = $source; rules = $rules }
$result | ConvertTo-Json -Depth 100
if ($DeleteMissing) { Write-Warning "DeleteMissing=true: import może usuwać obiekty nieobecne w YAML." }
