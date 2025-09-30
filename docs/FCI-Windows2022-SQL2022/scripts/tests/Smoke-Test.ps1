# Smoke test FCI: failover + zapytanie
param([string]$Vnn='SQLSRV-FCI',[string]$TargetNode='NODE2')
Move-ClusterGroup "SQL Server (MSSQLSERVER)" -Node $TargetNode
Start-Sleep -Seconds 10
sqlcmd -S $Vnn -l 60 -Q "SELECT @@SERVERNAME as NodeName, SYSDATETIMEOFFSET() as Now;"
