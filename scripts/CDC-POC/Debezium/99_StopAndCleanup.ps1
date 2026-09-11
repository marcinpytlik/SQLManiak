param(
    [switch]$RemoveVolumes
)

$ErrorActionPreference = 'Stop'
$compose = Join-Path $PSScriptRoot 'docker-compose.yml'

try {
    Invoke-RestMethod -Uri 'http://localhost:8083/connectors/sqllab-sqlserver-cdc' -Method Delete | Out-Null
    Write-Host 'Connector deleted.'
}
catch {
    Write-Host 'Connector was not deleted (it may already be absent or Kafka Connect may be stopped).'
}

if ($RemoveVolumes) {
    docker compose -f $compose down -v --remove-orphans
}
else {
    docker compose -f $compose down --remove-orphans
}

Write-Host 'Debezium/Kafka stack stopped.'
