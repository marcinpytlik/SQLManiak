# DBACentralRepository – TABLE USAGE v1.0

## Cel

Moduł odpowiada na dwa różne pytania i **nie miesza ich metryk**:

1. **Które tabele są faktycznie intensywnie używane?**  
   Snapshot `sys.dm_db_index_usage_stats` daje cumulative `user_seeks + user_scans + user_lookups` per tabela. Repozytorium przechowuje historię i liczy delty.

2. **Kto wykonuje SELECT na danej tabeli?**  
   SQL Server Audit (`SCHEMA_OBJECT_ACCESS_GROUP`) zapisuje principal, bazę, schema/object oraz statement. Collector importuje tylko akcję `SL` (SELECT), grupując dane w 5-minutowe buckety.

SQL Server Audit nie udostępnia logical reads per obiekt, dlatego raport nie przypisuje page reads do konkretnego loginu. `TechnicalAccessCount` i `OtherAccessCount` oznaczają **liczbę audytowanych dostępów SELECT**, a `UserReadsDelta` oznacza **łączny delta seeks/scans/lookups** tabeli.

**Granica interpretacji:** SQL Audit pokazuje obiekt, dla którego zarejestrowano audytowany dostęp. Przy dostępie przez widoki/procedury i ownership chaining nie należy automatycznie traktować principalowego `AccessCount` jako pełnej mapy wszystkich fizycznych tabel dotkniętych przez plan zapytania. Do decyzji o wycofaniu tabel zawsze zestawiaj Audit z `UserReadsDelta` oraz analizą zależności.

Na SQL Server 2016 collector zachowuje zgodność i może pozostawić `ApplicationName`/`HostName` jako `NULL`; od SQL Server 2017 pola te są dostępne w rekordach Audit.

## Pliki

- `24_Create_Table_Usage_Module.sql` – tabele, indeksy, konfiguracja, raport i retencja,
- `Install-TableAccessAudit.ps1` – tworzy/włącza SQL Server Audit na targetach,
- `Collect-TableUsage.ps1` – snapshot DMV + import SQL Audit,
- `25_Create_Table_Usage_Agent_Job.sql` – opcjonalny job co 5 minut.

## 1. Instalacja modułu w repozytorium

```sql
:r .\24_Create_Table_Usage_Module.sql
```

## 2. Konfiguracja bazy CRM

Najpierw upewnij się, że instancja istnieje już w `dbo.Instance`.

```sql
DECLARE @TargetId bigint;

EXEC perf.usp_ConfigureTableUsageTarget
    @ServerInstance = N'sql32',
    @DatabaseName = N'CRM',
    @AuditPath = N'D:\SQLAudit\DBACentralRepository\',
    @TableUsageTargetId = @TargetId OUTPUT;

SELECT @TargetId AS TableUsageTargetId;
```

Katalog musi istnieć na serwerze SQL i konto usługi SQL Server musi mieć do niego prawo zapisu.

## 3. Definicja kont technicznych

Wzorzec używa składni `LIKE`.

```sql
EXEC perf.usp_AddTableUsageTechnicalPrincipal
    @TableUsageTargetId = 1,
    @PrincipalPattern = N'MBANK\konto_techniczne',
    @Description = N'CRM technical account';
```

Możesz dodać wiele principal patterns, np. `N'MBANK\CRM_%'`.

## 4. Włączenie SQL Audit na serwerze źródłowym

Uruchom z konta mającego prawa do `CREATE/ALTER SERVER AUDIT` oraz `ALTER ANY DATABASE AUDIT`:

```powershell
.\Install-TableAccessAudit.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository'
```

Skrypt tworzy server audit oraz database audit specification z `SCHEMA_OBJECT_ACCESS_GROUP`.

## 5. Pierwszy collector

```powershell
.\Collect-TableUsage.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository'
```

Collector zapisuje snapshot DMV nawet wtedy, gdy import Audit nie powiedzie się.

## 6. Raport

```sql
EXEC perf.usp_GetTableUsageByPrincipal
    @ServerInstance = N'sql32',
    @DatabaseName = N'CRM',
    @From = DATEADD(day,-7,SYSUTCDATETIME()),
    @To = SYSUTCDATETIME(),
    @Top = 100;
```

Najważniejsze kolumny:

- `AccessCount` – liczba audytowanych SELECT,
- `TechnicalAccessCount` – SELECT wykonane przez principale techniczne,
- `OtherAccessCount` – SELECT pozostałych principalów,
- `TechnicalPercent` – udział kont technicznych w AccessCount,
- `UserReadsDelta` – zmiana cumulative seeks + scans + lookups,
- `UserUpdatesDelta` – zmiana cumulative user_updates.

## 7. Retencja

```sql
EXEC perf.usp_PurgeTableUsageHistory @RetentionDays=180;
```

## Uwaga o narzucie

`SCHEMA_OBJECT_ACCESS_GROUP` może generować dużo zdarzeń na bardzo aktywnej bazie. Na pierwszym wdrożeniu uruchom monitoring dla jednej bazy, obserwuj przyrost plików audit i koszt I/O, a dopiero potem rozszerzaj zakres.
