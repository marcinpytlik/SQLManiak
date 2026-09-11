$ErrorActionPreference = 'Stop'

$connectUrl = 'http://localhost:8083'
$name = 'sqllab-sqlserver-cdc'

Write-Host '=== Docker containers ==='
docker compose -f (Join-Path $PSScriptRoot 'docker-compose.yml') ps

Write-Host ''
Write-Host '=== Kafka Connect plugins ==='
Invoke-RestMethod -Uri "$connectUrl/connector-plugins" -Method Get |
    Where-Object { $_.class -match 'SqlServerConnector|debezium' } |
    Format-Table class, type, version -AutoSize

Write-Host ''
Write-Host '=== Connector status ==='
$status = Invoke-RestMethod -Uri "$connectUrl/connectors/$name/status" -Method Get
$status | ConvertTo-Json -Depth 20

if ($status.connector.state -ne 'RUNNING' -or ($status.tasks | Where-Object state -ne 'RUNNING')) {
    Write-Warning 'Connector or one of its tasks is not RUNNING. Check logs with: docker logs sqllab-debezium-connect --tail 200'
}
