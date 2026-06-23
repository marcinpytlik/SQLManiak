# SQL Agent Work Calendar - kompletne rozwiązanie, wersja poprawiona

Pakiet tworzy centralny kalendarz dni roboczych w `msdb` i pozwala używać go w SQL Agent Jobach.

## Co poprawiono

1. Poprawiono joby przykładowe:
   - nie ma już `RETURN 0` w krokach T-SQL SQL Agenta,
   - nie ma już skoków do nieistniejących kroków podczas tworzenia joba,
   - kroki mają numerację ciągłą `1`, `2`, `3`.

2. Poprawiono widok `dba.vWorkCalendarEnriched`:
   - usunięto konstrukcje generujące warning:
     `Null value is eliminated by an aggregate or other SET operation`.

3. Dodano `IsManualOverride`:
   - ręcznie ustawione dni firmowo wolne nie zostaną nadpisane przez ponowne uruchomienie skryptu wypełniającego kalendarz.

4. Skrypt testowy jest bezpieczny:
   - nie modyfikuje dzisiejszej daty,
   - testy na konkretnych datach używają parametru `@CheckDate`.

## Kolejność uruchamiania

1. `01_create_work_calendar_table.sql`
2. `02_fill_work_calendar_10_years_poland.sql`
3. `03_create_work_calendar_enriched_view.sql`
4. `04_create_work_calendar_check_procedures.sql`
5. Test:
   - `08_test_work_calendar.sql`
6. Opcjonalnie:
   - `05_example_job_variant_c_any_working_day.sql`
   - `06_example_job_variant_c_last_working_day.sql`
   - `07_add_schedules_examples.sql`
   - `09_manual_company_day_off_example.sql`
   - `10_job_step_templates.sql`

7. Sprzątanie / wycofanie pakietu:
   - `99_cleanup_work_calendar.sql`


## Sprzątanie środowiska

Jeżeli chcesz całkowicie wycofać pakiet z `msdb`, uruchom:

```sql
99_cleanup_work_calendar.sql
```

Skrypt usuwa:

- przykładowe joby SQL Agent,
- przykładowe harmonogramy,
- procedury `dba.usp_CheckWorkCalendarForSqlAgent` i `dba.usp_CheckWorkCalendarRuleForSqlAgent`,
- widok `dba.vWorkCalendarEnriched`,
- tabelę `dba.WorkCalendar`,
- schemat `dba`, ale tylko wtedy, gdy po sprzątaniu jest pusty.

Uwaga: skrypt usuwa również dane z kalendarza, ponieważ kasuje tabelę `msdb.dba.WorkCalendar`.

## Obiekty tworzone w msdb

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

Widok dodaje:

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

## Procedury

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

Przykład testu na konkretnej dacie:

```sql
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'ANY_WORKING_DAY',
    @CheckDate = '2026-06-23';

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

## Rekomendacja

W produkcji traktuj `msdb.dba.WorkCalendar` jako centralny kalendarz sterujący jobami.

Nie twórz osobnych kalendarzy w każdym jobie.
Nie hardkoduj list świąt w krokach jobów.
Nie opieraj się tylko na harmonogramie SQL Agenta, jeśli proces zależy od dnia roboczego.
