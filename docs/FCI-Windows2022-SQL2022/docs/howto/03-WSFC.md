# Windows Server Failover Cluster

Na **NODE1** (lub którykolwiek węzeł):
```powershell
.\scripts\cluster\New-WSFC.ps1 -ClusterName SQLLAB -ClusterIP 192.168.11.50 -WitnessPath \\DC\Quorum$ -Nodes NODE1,NODE2
```
