# DBACentralRepository – moduł PERF v1.0

## Cel

Moduł odpowiada na pytanie:

**Która baza danych najbardziej obciąża instancję SQL Server i w jakim zasobie?**

Nie wylicza jednego arbitralnego `Load %`. Pokazuje osobno udział w CPU, odczytach, zapisach, Buffer Pool, logu/transakcjach oraz obserwowanym blokowaniu.

## Integracja z repozytorium

Moduł korzysta z istniejącego `dbo.Instance` oraz wspólnego modułu PowerShell `modules/DBACentralRepository.Common`.

Dla szybkiego samplingu nie tworzy `dbo.ScanRun` co kilka minut. Używa własnego lekkiego `perf.SampleBatch`, dzięki czemu historia skanów inwentaryzacyjnych pozostaje czytelna.

## Pliki

- `20_Create_Perf_Module.sql` – schema/tabele/indeksy/procedury performance,
- `21_Create_Perf_Retention.sql` – retencja,
- `Collect-DatabasePerformance.ps1` – collector wszystkich aktywnych instancji z `dbo.Instance`,
- `22_Create_Grafana_Views.sql` – prezentacja danych dla Grafany,
- `23_Create_Perf_Agent_Job.sql` – niezależny job co 5 minut,
- `GRAFANA.md` i `grafana/*.json` – dashboardy.

## Pierwszy test

```powershell
.\Collect-DatabasePerformance.ps1 `
    -RepositoryServerInstance 'scrambler\sql2022' `
    -RepositoryDatabase 'DBACentralRepository'
```

Po co najmniej dwóch samplach:

```sql
EXEC perf.usp_GetDatabaseLoadRanking
    @ServerInstance = N'SQLPROD01',
    @From = DATEADD(hour,-1,SYSDATETIME()),
    @To = SYSDATETIME(),
    @Top = 20;
```

## Metodologia

### CPU

`perf.DatabaseCpuSnapshot` korzysta z `sys.dm_exec_query_stats` i atrybutu `dbid` planu. Jest to atrybucja na podstawie aktualnego plan cache. Restart, eviction planu lub recompilacja mogą powodować reset/spadek wartości i procedury raportowe nie interpretują tego jako ujemnego CPU.

### I/O

`sys.dm_io_virtual_file_stats` daje cumulative counters per plik. Repozytorium przechowuje stan, a raport liczy delty.

### Memory

`sys.dm_os_buffer_descriptors` pokazuje footprint danych bazy w Buffer Pool. Nie jest to całkowita pamięć wszystkich memory clerks przypisana do bazy.

### Blocking / waits

`sys.dm_exec_requests` jest samplingiem aktywnych requestów. Nie próbujemy przypisywać `sys.dm_os_wait_stats` do baz, bo są to statystyki poziomu instancji.

## Interwał

Zacznij od 5 minut. Po obserwacji narzutu można zejść do 1 minuty. Krótkotrwały blocking wymaga osobnego gęstszego samplera lub Extended Events; nie warto z tego powodu zagęszczać całego collectora.

## Retencja

```sql
EXEC perf.usp_PurgePerformanceHistory
    @RetentionDays = 90,
    @BatchSize = 5000;
```
