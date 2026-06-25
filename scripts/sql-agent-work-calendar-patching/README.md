# SQL Agent Work Calendar - kompletne rozwiązanie z modułem patchingowym

Pakiet tworzy centralny kalendarz dni roboczych w `msdb` i pozwala używać go w SQL Agent Jobach. Rozszerzona wersja zawiera dodatkowo moduł **SQL Agent Patching Window**, który pozwala przed patchowaniem SQL Server bezpiecznie wyłączyć wybrane joby SQL Server Agent, zapisać ich poprzedni stan i po patchowaniu przywrócić dokładnie te joby, które były wcześniej włączone.

## Co zawiera pakiet

1. Kalendarz dni roboczych w `msdb.dba.WorkCalendar`.
2. Widok wzbogacony `msdb.dba.vWorkCalendarEnriched`.
3. Procedury do sprawdzania reguł kalendarza w jobach SQL Agent.
4. Przykładowe joby sterowane kalendarzem.
5. Szablony kroków SQL Agent.
6. Moduł patchingowy do kontrolowanego wyłączania i przywracania jobów.
7. Skrypt testowy modułu patchingowego.
8. Skrypt cleanup do wycofania pakietu.

## Kolejność uruchamiania

Podstawowy kalendarz:

1. `01_create_work_calendar_table.sql`
2. `02_fill_work_calendar_10_years_poland.sql`
3. `03_create_work_calendar_enriched_view.sql`
4. `04_create_work_calendar_check_procedures.sql`
5. Test kalendarza:
   - `08_test_work_calendar.sql`

Przykłady i szablony kalendarza:

6. Opcjonalnie:
   - `05_example_job_variant_c_any_working_day.sql`
   - `06_example_job_variant_c_last_working_day.sql`
   - `07_add_schedules_examples.sql`
   - `09_manual_company_day_off_example.sql`
   - `10_job_step_templates.sql`

Moduł patchingowy:

7. `11_create_patching_job_control_tables.sql`
8. Przykład wyłączenia jobów przed patchowaniem:
   - `12_example_patching_window_disable_jobs.sql`
9. Przykład przywrócenia jobów po patchowaniu:
   - `13_example_patching_window_restore_jobs.sql`
10. Test modułu patchingowego:
   - `14_test_patching_job_control.sql`

Sprzątanie / wycofanie pakietu:

11. `99_cleanup_work_calendar.sql`

## Obiekty kalendarza

### Tabela

```sql
msdb.dba.WorkCalendar
```

Najważniejsze kolumny:

| Kolumna | Znaczenie |
|---|---|
| `CalendarDate` | data |
| `IsWorkingDay` | `1` = dzień roboczy, `0` = dzień wolny |
| `Description` | opis dnia |
| `IsManualOverride` | `1` = wpis ręcznie ustawiony i chroniony przed nadpisaniem |
| `CreatedAt` | data utworzenia wpisu |
| `ModifiedAt` | data ostatniej modyfikacji |

### Widok

```sql
msdb.dba.vWorkCalendarEnriched
```

Widok dodaje m.in.:

| Kolumna | Znaczenie |
|---|---|
| `CalendarYear` | rok |
| `CalendarMonth` | miesiąc |
| `DayNamePL` | nazwa dnia po polsku |
| `IsWeekend` | czy weekend |
| `IsHolidayOrCompanyDayOff` | czy święto lub dzień firmowo wolny |
| `FirstWorkingDayOfMonth` | pierwszy dzień roboczy miesiąca |
| `LastWorkingDayOfMonth` | ostatni dzień roboczy miesiąca |
| `IsFirstWorkingDayOfMonth` | flaga pierwszego dnia roboczego miesiąca |
| `IsLastWorkingDayOfMonth` | flaga ostatniego dnia roboczego miesiąca |
| `WorkingDayNumberInMonth` | numer dnia roboczego w miesiącu |
| `WorkingDaysInMonth` | liczba dni roboczych w miesiącu |
| `PreviousWorkingDay` | poprzedni dzień roboczy |
| `NextWorkingDay` | następny dzień roboczy |

## Procedury kalendarza

### Podstawowe sprawdzenie

```sql
msdb.dba.usp_CheckWorkCalendarForSqlAgent
```

Kody zwrotne:

| Kod | Znaczenie |
|---:|---|
| `0` | dzień roboczy |
| `10` | dzień wolny |
| `99` | brak wpisu w kalendarzu / błąd konfiguracji |

### Sprawdzenie reguł

```sql
msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
```

Obsługiwane reguły:

| Reguła | Znaczenie |
|---|---|
| `ANY_WORKING_DAY` | dowolny dzień roboczy |
| `FIRST_WORKING_DAY_OF_MONTH` | pierwszy dzień roboczy miesiąca |
| `LAST_WORKING_DAY_OF_MONTH` | ostatni dzień roboczy miesiąca |
| `NTH_WORKING_DAY_OF_MONTH` | N-ty dzień roboczy miesiąca |

Przykład:

```sql
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'LAST_WORKING_DAY_OF_MONTH';

SELECT @ReturnCode AS ReturnCode;
```

## Model joba - wariant C

Struktura przykładowa:

| Step ID | Nazwa |
|---:|---|
| 1 | Check calendar rule |
| 2 | Decide controlled skip or real failure |
| 3 | Business step 1 |

Logika:

| Sytuacja | Efekt |
|---|---|
| reguła spełniona | krok 1 kończy się sukcesem i job przechodzi do kroku 3 |
| reguła niespełniona | krok 1 celowo zgłasza `CONTROLLED_SKIP`, przechodzi do kroku 2, a cały job kończy się sukcesem |
| brak daty / błąd kalendarza | krok 2 rozpoznaje błąd i job kończy się błędem |

W historii joba przy controlled skip krok 1 może być czerwony, ponieważ celowo używa `RAISERROR('CONTROLLED_SKIP', 16, 1)`. Ważny jest końcowy status joba: `The job succeeded`.

## Moduł SQL Agent Patching Window

Moduł patchingowy jest przeznaczony do obsługi okna serwisowego SQL Server. Jego zadaniem jest:

- założenie operacji patchowania,
- pokazanie, które joby zostaną wyłączone,
- wyłączenie wybranych jobów SQL Agent,
- zapisanie snapshotu ich poprzedniego stanu,
- przywrócenie po patchowaniu tylko tych jobów, które wcześniej były włączone i zostały wyłączone przez narzędzie,
- raportowanie aktualnego stanu względem snapshotu.

### Czego moduł nie robi

Moduł nie usuwa jobów, nie zmienia ich kroków, harmonogramów ani właścicieli. Nie aktualizuje bezpośrednio tabel systemowych SQL Agent. Do zmiany stanu joba używa procedury:

```sql
msdb.dbo.sp_update_job
```

### Tabele modułu patchingowego

```sql
msdb.dba.SqlAgentPatchingRun
msdb.dba.SqlAgentPatchingJobState
```

`SqlAgentPatchingRun` przechowuje informacje o oknie patchowania.

`SqlAgentPatchingJobState` przechowuje snapshot jobów oraz informację, czy job został wyłączony przez narzędzie i czy został później przywrócony.

### Procedury modułu patchingowego

```sql
msdb.dba.usp_StartSqlAgentPatchingWindow
msdb.dba.usp_DisableSqlAgentJobsForPatching
msdb.dba.usp_RestoreSqlAgentJobsAfterPatching
msdb.dba.usp_ReportSqlAgentPatchingWindow
```

## Jak wykonać Preview przed patchowaniem

```sql
DECLARE @PatchingRunId int;

EXEC msdb.dba.usp_StartSqlAgentPatchingWindow
    @Description = N'Patchowanie SQL Server - okno serwisowe 2026-06',
    @PlannedStartDateTime = '2026-06-23T22:00:00',
    @PlannedEndDateTime = '2026-06-23T23:30:00',
    @PatchingRunId = @PatchingRunId OUTPUT;

EXEC msdb.dba.usp_DisableSqlAgentJobsForPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Preview',
    @JobNameLike = NULL,
    @CategoryName = NULL,
    @ExcludeJobNameLike = NULL,
    @ExcludeJobNameList = N'DBA - Monitoring,DBA - Alerting',
    @IncludeBackupJobs = 0,
    @IncludeMonitoringJobs = 0,
    @Comment = N'Preview przed patchowaniem';
```

## Jak wykonać Disable przed patchowaniem

```sql
EXEC msdb.dba.usp_DisableSqlAgentJobsForPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Execute',
    @JobNameLike = NULL,
    @CategoryName = NULL,
    @ExcludeJobNameLike = NULL,
    @ExcludeJobNameList = N'DBA - Monitoring,DBA - Alerting',
    @IncludeBackupJobs = 0,
    @IncludeMonitoringJobs = 0,
    @Comment = N'Wyłączenie jobów przed patchowaniem SQL Server';
```

## Jak wykonać Report

```sql
EXEC msdb.dba.usp_ReportSqlAgentPatchingWindow
    @PatchingRunId = @PatchingRunId;
```

Raport pokazuje:

- informacje o oknie patchowania,
- joby wyłączone przez narzędzie,
- joby pominięte,
- joby przywrócone,
- joby nieprzywrócone,
- aktualny stan jobów względem zapisanego snapshotu.

## Jak wykonać Restore po patchowaniu

```sql
EXEC msdb.dba.usp_RestoreSqlAgentJobsAfterPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Preview',
    @Comment = N'Preview restore po patchowaniu';

EXEC msdb.dba.usp_RestoreSqlAgentJobsAfterPatching
    @PatchingRunId = @PatchingRunId,
    @Mode = N'Execute',
    @Comment = N'Przywrócenie jobów po patchowaniu SQL Server';
```

Restore włącza tylko te joby, które:

- były włączone przed patchowaniem,
- zostały wyłączone przez moduł patchingowy,
- nadal istnieją w SQL Agent.

Restore nie włącza jobów, które przed patchowaniem były wyłączone.

## Joby domyślnie chronione

Domyślnie procedura `usp_DisableSqlAgentJobsForPatching` nie wyłącza jobów, których nazwa zawiera:

- `Backup`
- `LOG`
- `Monitoring`
- `Alert`
- `DBA`
- `Restore`
- `CheckDB`
- `Integrity`

Joby te są widoczne w raporcie jako pominięte.

Aby świadomie dopuścić wyłączenie części z nich, użyj:

```sql
@IncludeBackupJobs = 1
@IncludeMonitoringJobs = 1
```

## Jak dopisać wyjątki

Możesz pominąć joby przez wzorzec:

```sql
@ExcludeJobNameLike = N'DBA - Monitoring%'
```

albo przez listę nazw rozdzielonych przecinkiem:

```sql
@ExcludeJobNameList = N'DBA - Monitoring,DBA - Alerting'
```

## Wymagane uprawnienia

Do uruchomienia pełnego modułu użytkownik musi mieć możliwość:

- odczytu jobów SQL Server Agent,
- wykonania `msdb.dbo.sp_update_job`,
- tworzenia i wykonywania procedur w `msdb.dba`,
- odczytu i zapisu do tabel `msdb.dba.SqlAgentPatchingRun` oraz `msdb.dba.SqlAgentPatchingJobState`.

W praktyce dla wdrożenia pakietu wymagane są uprawnienia administracyjne w `msdb`. Do samego operacyjnego użycia w środowisku produkcyjnym można przygotować dedykowaną rolę i nadać jej prawa do wykonywania procedur z `msdb.dba`. Jeżeli środowisko ma restrykcyjne zasady bezpieczeństwa, decyzję o minimalnych uprawnieniach należy potwierdzić z DBA / właścicielem instancji.

## Jak przetestować rozwiązanie przed produkcją

Uruchom:

```sql
14_test_patching_job_control.sql
```

Test tworzy joby o nazwach zaczynających się od:

```text
SQLManiak TEST Patching
```

Następnie sprawdza:

- Preview,
- Execute wyłączenia,
- pominięcie joba krytycznego zawierającego `Backup`,
- przywrócenie tylko joba, który był wcześniej włączony,
- pozostawienie wyłączonego joba w stanie wyłączonym,
- sprzątanie testowych jobów.

## Dni firmowe

Automat oznacza:

- soboty,
- niedziele,
- polskie święta stałe,
- polskie święta ruchome,
- Wigilię 24 grudnia.

Dni firmowe, mostki i dni wolne za święta przypadające w sobotę oznaczaj ręcznie.

Przykład:

```sql
UPDATE msdb.dba.WorkCalendar
SET
    IsWorkingDay = 0,
    Description = N'Dzień wolny firmowy za święto przypadające w sobotę',
    IsManualOverride = 1,
    ModifiedAt = sysdatetime()
WHERE CalendarDate = '2026-08-14';
```

`IsManualOverride = 1` powoduje, że skrypt `02_fill_work_calendar_10_years_poland.sql` nie nadpisze ręcznej decyzji.

## Sprzątanie środowiska

Jeżeli chcesz całkowicie wycofać pakiet z `msdb`, uruchom:

```sql
99_cleanup_work_calendar.sql
```

Skrypt usuwa:

- przykładowe joby SQL Agent,
- przykładowe harmonogramy,
- procedury kalendarza,
- procedury modułu patchingowego,
- tabele modułu patchingowego,
- widok `dba.vWorkCalendarEnriched`,
- tabelę `dba.WorkCalendar`,
- schemat `dba`, ale tylko wtedy, gdy po sprzątaniu jest pusty.

Uwaga: skrypt usuwa również dane z kalendarza i historię okien patchowania.

## Rekomendacja produkcyjna

W produkcji traktuj `msdb.dba.WorkCalendar` jako centralny kalendarz sterujący jobami, a moduł `SQL Agent Patching Window` jako narzędzie do kontrolowanej obsługi okna serwisowego.

Nie twórz osobnych kalendarzy w każdym jobie. Nie hardkoduj list świąt w krokach jobów. Nie wyłączaj jobów ręcznie bez snapshotu, jeżeli po patchowaniu chcesz mieć pewność, które joby należy przywrócić.
