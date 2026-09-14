$ErrorActionPreference = 'Stop'

$connectUrl = 'http://localhost:8083'
$templatePath = Join-Path $PSScriptRoot 'connector-sqlserver.template.json'

try {
    Invoke-RestMethod -Uri "$connectUrl/connectors" -Method Get | Out-Null
}
catch {
    throw "Kafka Connect REST API is not reachable at $connectUrl. Start the stack first with .\01_Start.ps1 and wait until Connect is ready."
}

$password = $env:DEBEZIUM_SQL_PASSWORD
if ([string]::IsNullOrWhiteSpace($password)) {
    $secure = Read-Host 'Password for SQL login debezium' -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try {
        $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

$sqlHost = $env:DEBEZIUM_SQL_HOST
if ([string]::IsNullOrWhiteSpace($sqlHost)) {
    $sqlHost = 'sql64'
}

$config = Get-Content $templatePath -Raw | ConvertFrom-Json
$config.config.'database.password' = $password
$config.config.'database.hostname' = $sqlHost

$name = $config.name
$existing = $null
try {
    $existing = Invoke-RestMethod -Uri "$connectUrl/connectors/$name" -Method Get
}
catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw }
}

if ($null -eq $existing) {
    $body = $config | ConvertTo-Json -Depth 20
    $result = Invoke-RestMethod -Uri "$connectUrl/connectors" -Method Post -ContentType 'application/json' -Body $body
    Write-Host "Connector '$name' created for SQL host '$sqlHost'."
}
else {
    $body = $config.config | ConvertTo-Json -Depth 20
    $result = Invoke-RestMethod -Uri "$connectUrl/connectors/$name/config" -Method Put -ContentType 'application/json' -Body $body
    Write-Host "Connector '$name' configuration updated for SQL host '$sqlHost'."
}

Write-Host ''
Write-Host 'Current status:'
Invoke-RestMethod -Uri "$connectUrl/connectors/$name/status" -Method Get | ConvertTo-Json -Depth 20
