param(
    [ValidateSet('Customer','CustomerOrder')]
    [string]$Table = 'Customer',
    [switch]$FromBeginning
)

$ErrorActionPreference = 'Stop'
$compose = Join-Path $PSScriptRoot 'docker-compose.yml'
$topic = "sqllab.CDC_Lab.dbo.$Table"

$args = @(
    'compose', '-f', $compose, 'exec', 'kafka',
    '/kafka/bin/kafka-console-consumer.sh',
    '--bootstrap-server', 'kafka:9092',
    '--topic', $topic,
    '--property', 'print.key=true',
    '--property', 'key.separator= | '
)

if ($FromBeginning) {
    $args += '--from-beginning'
}

Write-Host "Consuming topic: $topic"
Write-Host 'Press Ctrl+C to stop.'
& docker @args
