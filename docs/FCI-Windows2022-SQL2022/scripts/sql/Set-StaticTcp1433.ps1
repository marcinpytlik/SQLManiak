# Wymuszenie TCP 1433 (MSSQLSERVER) + restart zasobu w klastrze
$reg='HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.MSSQLSERVER\MSSQLServer\SuperSocketNetLib\Tcp\IPAll'
Set-ItemProperty $reg TcpDynamicPorts ''
Set-ItemProperty $reg TcpPort '1433'
Stop-ClusterResource "SQL Server (MSSQLSERVER)"
Start-ClusterResource "SQL Server (MSSQLSERVER)"
