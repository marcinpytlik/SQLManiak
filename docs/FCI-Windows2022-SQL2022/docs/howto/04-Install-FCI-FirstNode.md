# SQL Server 2022 FCI — pierwszy węzeł (InstallFailoverCluster)

1) Zweryfikuj nazwę sieci klastra:  
```powershell
Get-ClusterNetwork | ft Name,Address,PrefixLength,Role
```
2) Wyedytuj `scripts/sql/Install-FCI-FirstNode.ini` (dyski, sieć, konta).  
3) Na **NODE1**:  
```powershell
D:\setup.exe /Q /IACCEPTSQLSERVERLICENSETERMS /ConfigurationFile="C:\Temp\Install-FCI-FirstNode.ini"
```
Jeśli nie masz jeszcze lokalnego `T:\MSSQL`, usuń `SQLTEMPDBDIR` z INI i przenieś tempdb po instalacji (patrz: `07-TempDB-Local.md`).
