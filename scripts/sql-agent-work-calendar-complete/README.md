# SQL Agent Work Calendar - kompletne rozwiązanie

Pakiet tworzy centralny kalendarz dni roboczych w `msdb` i pozwala używać go w SQL Agent Jobach.

## Co zawiera

```text
sql-agent-work-calendar-complete/
├── 01_create_work_calendar_table.sql
├── 02_fill_work_calendar_10_years_poland.sql
├── 03_create_work_calendar_enriched_view.sql
├── 04_create_work_calendar_check_procedures.sql
├── 05_example_job_variant_c_any_working_day.sql
├── 06_example_job_variant_c_last_working_day.sql
├── 07_add_schedules_examples.sql
├── 08_test_work_calendar.sql
├── 09_manual_company_day_off_example.sql
├── 10_job_step_templates.sql
└── README.md
```

## Kolejność uruchamiania

1. `01_create_work_calendar_table.sql`
2. `02_fill_work_calendar_10_years_poland.sql`
3. `03_create_work_calendar_enriched_view.sql`
4. `04_create_work_calendar_check_procedures.sql`
5. Opcjonalnie:
   - `05_example_job_variant_c_any_working_day.sql`
   - `06_example_job_variant_c_last_working_day.sql`
   - `07_add_schedules_examples.sql`
6. Testy:
   - `08_test_work_calendar.sql`

## Obiekty tworzone w msdb

### Tabela

```sql
msdb.dba.WorkCalendar
```

To jest źródło prawdy.

| Kolumna | Znaczenie |
|---|---|
| `CalendarDate` | data |
| `IsWorkingDay` | `1` = dzień roboczy, `0` = dzień wolny |
| `Description` | opis dnia |
| `CreatedAt` | data utworzenia wpisu |
| `ModifiedAt` | data ostatniej modyfikacji |

### Widok

```sql
msdb.dba.vWorkCalendarEnriched
```

Widok dodaje między innymi:

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
| `99` | brak wpisu w kalendarzu |

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

Przykład dla trzeciego dnia roboczego miesiąca:

```sql
DECLARE @ReturnCode int;

EXEC @ReturnCode = msdb.dba.usp_CheckWorkCalendarRuleForSqlAgent
    @RuleName = N'NTH_WORKING_DAY_OF_MONTH',
    @WorkingDayNumberInMonth = 3;

SELECT @ReturnCode AS ReturnCode;
```

## Model joba - wariant C

Struktura:

| Step ID | Nazwa |
|---:|---|
| 1 | Check calendar rule |
| 2 | Decide controlled skip or real failure |
| 10 | Business step 1 |
| 20 | Business step 2 |

Logika:

| Sytuacja | Efekt |
|---|---|
| reguła spełniona | job przechodzi do właściwych kroków |
| reguła niespełniona | job kończy się kontrolowanie jako sukces |
| brak daty / błąd kalendarza | job kończy się błędem |

## Przykłady zastosowania

### Job codzienny, ale wykonuje się tylko w dzień roboczy

Użyj reguły:

```sql
ANY_WORKING_DAY
```

### Job miesięczny, ale wykonuje się tylko w ostatni dzień roboczy miesiąca

Użyj reguły:

```sql
LAST_WORKING_DAY_OF_MONTH
```

### Job po zamknięciu księgowym, np. trzeci dzień roboczy miesiąca

Użyj reguły:

```sql
NTH_WORKING_DAY_OF_MONTH
```

z parametrem:

```sql
@WorkingDayNumberInMonth = 3
```

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
    ModifiedAt = sysdatetime()
WHERE CalendarDate = '2026-08-14';
```

## Rekomendacja

W produkcji traktuj `msdb.dba.WorkCalendar` jako centralny kalendarz sterujący jobami.

Nie twórz osobnych kalendarzy w każdym jobie.
Nie hardkoduj list świąt w krokach jobów.
Nie opieraj się tylko na harmonogramie SQL Agenta, jeśli proces zależy od dnia roboczego.
