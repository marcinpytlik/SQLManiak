$ErrorActionPreference = 'Stop'

$kafkaContainer = 'sqllab-kafka'

Write-Host '=== TEST 02: Restart Kafka ==='
Write-Host '1. Current container state:'
docker ps --format 'table {{.Names}}\t{{.Status}}' | Out-Host

Write-Host '2. Stopping Kafka...'
docker stop $kafkaContainer | Out-Host
Start-Sleep -Seconds 3

Write-Host ''
Write-Host '3. While Kafka is stopped, execute a small INSERT/UPDATE in CDC_Lab.'
Write-Host @'
USE CDC_Lab;
GO
INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('Kafka','Restart','kafka.restart@test.local');
GO
UPDATE dbo.Customer
SET Email = 'kafka.restart.changed@test.local',
    ModifiedDate = SYSUTCDATETIME()
WHERE LastName = 'Restart' AND FirstName = 'Kafka';
GO
'@

Read-Host 'Press ENTER after the SQL changes are committed'

Write-Host '4. Starting Kafka...'
docker start $kafkaContainer | Out-Host
Start-Sleep -Seconds 15

Write-Host '5. Connector status:'
& (Join-Path $PSScriptRoot '..\Debezium\03_Status.ps1')

Write-Host ''
Write-Host 'PASS criteria:'
Write-Host '- Kafka returns to Up'
Write-Host '- connector/task returns to RUNNING'
Write-Host '- changes created during Kafka outage are eventually published after recovery'
