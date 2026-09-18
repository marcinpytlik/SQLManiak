param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl,

    [string]$TemplateName = "SQLManiak MSSQL by Zabbix agent 2",

    [string]$OutputPath = (Join-Path $PSScriptRoot "..\templates\SQLManiak_MSSQL_Zabbix_7.4_matrix_v1.6_baseline_anomaly.yaml"),

    [string]$ApiToken = $env:ZABBIX_API_TOKEN
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiToken)) {
    throw "Brak tokena API. Przekaż -ApiToken albo ustaw zmienną środowiskową ZABBIX_API_TOKEN."
}

function Invoke-ZabbixApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Method,
        [Parameter(Mandatory = $true)]
        [object]$Params
    )

    $payload = @{
        jsonrpc = "2.0"
        method  = $Method
        params  = $Params
        id      = 1
    } | ConvertTo-Json -Depth 100

    $headers = @{ Authorization = "Bearer $ApiToken" }

    $response = Invoke-RestMethod -Method Post -Uri $ApiUrl -Headers $headers -ContentType "application/json-rpc" -Body $payload

    if ($null -ne $response.error) {
        $details = $response.error | ConvertTo-Json -Depth 20 -Compress
        throw "Błąd Zabbix API dla $Method : $details"
    }
    return $response.result
}

$template = Invoke-ZabbixApi -Method "template.get" -Params @{
    output = @("templateid", "host", "name")
    filter = @{ host = @($TemplateName) }
}

if (-not $template -or $template.Count -eq 0) { throw "Nie znaleziono szablonu $TemplateName." }
if ($template.Count -gt 1) { throw "Znaleziono więcej niż jeden szablon pasujący do $TemplateName." }

$templateId = [string]$template[0].templateid
$yaml = Invoke-ZabbixApi -Method "configuration.export" -Params @{
    format = "yaml"
    prettyprint = $true
    options = @{ templates = @($templateId) }
}

$fullPath = [System.IO.Path]::GetFullPath($OutputPath)
$directory = [System.IO.Path]::GetDirectoryName($fullPath)
if (-not (Test-Path $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($fullPath, [string]$yaml, $utf8NoBom)
$hash = (Get-FileHash -Path $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host "Wyeksportowano szablon: $TemplateName"
Write-Host "Template ID: $templateId"
Write-Host "Plik: $fullPath"
Write-Host "SHA256: $hash"
Write-Host ""
Write-Host "Następny krok: git diff -- scripts/zabbix-mssql-monitoring/templates"
