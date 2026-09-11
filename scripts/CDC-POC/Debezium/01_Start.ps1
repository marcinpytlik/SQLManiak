$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot

if (-not (Test-Path '.env')) {
    Copy-Item '.env.example' '.env'
    Write-Host 'Created .env from .env.example'
}

docker compose --env-file .env up -d

Write-Host ''
Write-Host 'Containers:'
docker compose ps

Write-Host ''
Write-Host 'Kafka Connect REST API should become available at http://localhost:8083'
Write-Host 'Run .\02_RegisterConnector.ps1 after Connect is ready.'
