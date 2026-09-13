$ErrorActionPreference = 'Stop'

$compose = Join-Path $PSScriptRoot '..\Debezium\docker-compose.yml'
$connectContainer = 'sqllab-debezium-connect'

Write-Host '=== TEST 01: Restart Debezium Connect ==='
Write-Host '1. Stopping Debezium Connect...'
docker stop $connectContainer | Out-Host

Write-Host ''
Write-Host '2. Execute the following SQL in SSMS while Connect is stopped:'
Write-Host @'
USE CDC_Lab;
GO
INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('Restart','Test1','restart1@test.local');
GO
INSERT dbo.Customer (FirstName, LastName, Email)
VALUES ('Restart','Test2','restart2@test.local');
GO
UPDATE dbo.Customer
SET Email = 'restart2_changed@test.local',
    ModifiedDate = SYSUTCDATETIME()
WHERE LastName = 'Test2';
GO
'@

Read-Host 'Press ENTER after the SQL changes are committed and visible in cdc.dbo_Customer_CT'

Write-Host '3. Starting Debezium Connect...'
docker start $connectContainer | Out-Host
Start-Sleep -Seconds 10

Write-Host '4. Connector status:'
& (Join-Path $PSScriptRoot '..\Debezium\03_Status.ps1')

Write-Host ''
Write-Host 'PASS criteria:'
Write-Host '- connector and task are RUNNING'
Write-Host '- consumer receives INSERT Test1, INSERT Test2 and UPDATE Test2'
Write-Host '- no gap is observed in the expected business changes'
