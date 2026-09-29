# SQL Server FCI Failover — VALIDATION

## 1. Owner node

```powershell
Get-ClusterGroup "SQL Server (MSSQLSERVER)"
```

Potwierdź, że ownerem jest target node.

## 2. Cluster resources

Potwierdź stan wymaganych zasobów:

- SQL Server,
- SQL Server Agent,
- Network Name / VNN,
- IP Address,
- shared DATA/LOG disks.

## 3. SQL connectivity przez VNN

```powershell
sqlcmd -S <VNN> -l 60 -Q "SELECT @@SERVERNAME AS ServerName, SYSDATETIMEOFFSET() AS Now;"
```

Waliduj przez VNN, nie przez fizyczną nazwę node.

## 4. TempDB

Zgodnie z repozytoryjną checklistą:

- sprawdź ERRORLOG pod kątem tworzenia TempDB,
- zweryfikuj liczbę i rozmiary plików,
- potwierdź utworzenie logu TempDB.

Przykład kontroli:

```sql
USE tempdb;
SELECT
    name,
    physical_name,
    size * 8.0 / 1024 AS size_mb
FROM sys.database_files;
```

## 5. SQL Agent

Potwierdź, że SQL Server Agent działa po failover.

Powiązany troubleshooting:

- [SQL Agent](../../troubleshooting/sql-agent/)

## 6. Aplikacja

Zmierz rzeczywisty okres:

```text
disconnect:
reconnect:
total interruption:
```

Repozytoryjna checklista TempDB zaleca pomiar czasu od disconnect do reconnect aplikacji.

## 7. Evidence

Zachowaj:

- owner node przed/po,
- output `Get-ClusterGroup`,
- stan resources,
- wynik połączenia przez VNN,
- ERRORLOG po starcie,
- stan TempDB,
- czas przełączenia,
- wpływ na aplikację.
