# Przeniesienie tempdb na lokalny dysk T:\

Na **aktywnym** węźle FCI:
```powershell
sqlcmd -S SQLSRV-FCI -i .\scripts\sql\Move-Tempdb-Local.sql
# potem restart roli SQL w klastrze
```
Upewnij się, że ścieżka `T:\MSSQL` istnieje na **obu** węzłach.
