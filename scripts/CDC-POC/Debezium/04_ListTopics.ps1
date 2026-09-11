$ErrorActionPreference = 'Stop'

$compose = Join-Path $PSScriptRoot 'docker-compose.yml'

docker compose -f $compose exec kafka /kafka/bin/kafka-topics.sh `
    --bootstrap-server kafka:9092 `
    --list | Sort-Object
