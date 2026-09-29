# Troubleshooting: Query Store

Query Store jest historycznym źródłem wiedzy o zapytaniach, planach i ich zachowaniu w czasie.

Największa wartość diagnostyczna Query Store pojawia się wtedy, gdy pytanie brzmi:

> **Co zmieniło się między okresem, kiedy było dobrze, a okresem, kiedy zaczęło być źle?**

---

# Diagnostic flow

```text
Application slowdown / query regression
            |
            v
Define incident window
            |
            v
Confirm Query Store state
            |
            v
Find query_id
            |
            v
Compare runtime stats
            |
            v
Compare plan_id values
            |
            v
Check waits / CPU / reads / duration
            |
            v
Identify regression
            |
            v
Choose action
      +-----+----------------------+
      |                            |
 observe/tune               controlled intervention
      |                            |
      |                  force plan / Query Store Hint
      |                            |
      +-------------+--------------+
                    |
                    v
                 validate
                    |
                    v
              unforce/remove if needed
```

---

# 1. First checks

1. Sprawdź, czy Query Store jest włączony.
2. Sprawdź `actual_state_desc` i `desired_state_desc`.
3. Sprawdź, czy baza jest w `READ_WRITE`, a nie `READ_ONLY`.
4. Ustal dokładne okno incydentu.
5. Zidentyfikuj `query_id`.
6. Sprawdź wszystkie `plan_id`.
7. Porównaj runtime statistics między okresami.
8. Sprawdź CPU, duration, logical reads i execution count.
9. Jeżeli dostępne, sprawdź Query Store wait stats.
10. Dopiero potem podejmij decyzję o forcingu lub hintach.

---

# 2. Existing sources of truth

## Query regression lab

- [Lab 01 – Query Store Regression](../../labs/01-query-store-regression/)
- [Force plan example](../../labs/01-query-store-regression/04_force_plan.sql)

Lab prowadzi przez:

```text
baseline
→ regression
→ analysis
→ force plan
```

## Force Plan / QCR-like

- [Lab 06 – Query Store Force Plan](../../labs/06-internals/Lab06_QueryStore_ForcePlan_QCR/)
- [Find and force plan](../../labs/06-internals/Lab06_QueryStore_ForcePlan_QCR/scripts/03_find_and_force_plan.sql)
- [Forced vs unforced test](../../labs/06-internals/Lab06_QueryStore_ForcePlan_QCR/scripts/04_test_forced_vs_unforced.sql)

## Query Store Hints

- [Lab 09 – Query Store Hints](../../labs/06-internals/Lab09_QueryStore_Hints_SQL2022/)

## Query lookup / incident analysis

- [Request PerfPack – Query Store](../../scripts/t-sql/Reques_PerfPack/01_QueryStore_FindQueries.sql)

## Compatibility level migration

- [QS Compat Report](../../scripts/t-sql/database/QS-Compat-Report/)
- [README](../../scripts/t-sql/database/QS-Compat-Report/README.md)

## Operational checklist

- [Query Store Checklist](../../labs/QueryStore/checklists/QueryStore-Checklist.md)

## VLDB

- [Query Store VLDB Runbook](../../docs/VLDB_Survival_Kit_SQLServer_2022/RUNBOOKS/QueryStore-VLDB.md)
- [VLDB configuration script](../../docs/VLDB_Survival_Kit_SQLServer_2022/SCRIPTS/TSQL/20_querystore_vldb.sql)

---

# 3. Query Store state

Zanim zaczniesz analizować dane, sprawdź stan Query Store.

Interesują Cię co najmniej:

```text
actual_state_desc
desired_state_desc
current_storage_size_mb
max_storage_size_mb
readonly_reason
query_capture_mode_desc
```

Jeżeli Query Store jest w `READ_ONLY`, to nie zakładaj, że historia jest kompletna.

Możliwe przyczyny wymagają osobnej weryfikacji, np.:

- osiągnięcie limitu rozmiaru,
- stan bazy,
- problem operacyjny,
- ręczna konfiguracja.

Repo zawiera również politykę PBM:

- [PBM Query Store](../../scripts/PBM_QueryStore.md)

której celem jest wykrywanie baz, gdzie Query Store nie działa w oczekiwanym trybie.

---

# 4. Zaczynaj od okna incydentu

Najbardziej użyteczny model to:

```text
BEFORE window
vs
AFTER / INCIDENT window
```

Przykład:

```text
BEFORE:
2026-09-20 10:00-11:00

INCIDENT:
2026-09-27 10:00-11:00
```

Porównuj podobne okresy workloadu.

Nie porównuj automatycznie:

```text
noc
vs
godzina szczytu
```

bo różnica może wynikać z profilu obciążenia, a nie z regresji planu.

---

# 5. Znajdź query_id

Repo zawiera dwa praktyczne sposoby.

## Po tabeli / oknie czasu

- [01_QueryStore_FindQueries.sql](../../scripts/t-sql/Reques_PerfPack/01_QueryStore_FindQueries.sql)

Skrypt jest przygotowany właśnie pod analizę incydentu i zwraca m.in.:

```text
query_id
plan_id
query_hash
query_plan_hash
avg_duration
avg_cpu_time
avg_logical_io_reads
```

## Po fragmencie tekstu

- [QSH_Find_Query_ByText.sql](../../labs/06-internals/QueryStoreHints/scripts/QSH_Find_Query_ByText.sql)

To przydaje się, gdy znasz fragment SQL, ale nie znasz `query_id`.

---

# 6. Query ID i Plan ID to podstawowe identyfikatory

Podczas analizy zapisuj:

```text
query_id
plan_id
query_hash
query_plan_hash
```

Nie wystarczy powiedzieć:

> to zapytanie było wolne.

Potrzebujesz odpowiedzieć:

- czy query miało jeden czy wiele planów?
- kiedy pojawił się nowy plan?
- który plan działał w dobrym okresie?
- który plan działał podczas regresji?

---

# 7. Runtime statistics

Porównuj przede wszystkim:

```text
count_executions
avg_duration
avg_cpu_time
avg_logical_io_reads
max_duration
```

W zależności od konkretnego raportu mogą być dostępne także inne statystyki runtime.

Najważniejsze jest porównanie **tego samego query_id między przedziałami czasu i planami**.

---

# 8. Regression nie oznacza automatycznie „zły plan”

Przykład:

```text
BEFORE
plan_id = 5
avg_duration = 100 ms

AFTER
plan_id = 8
avg_duration = 1500 ms
```

To jest mocny sygnał, ale nadal sprawdź:

- CPU,
- reads,
- waits,
- execution count,
- zmianę danych,
- concurrency,
- parametry,
- execution plan.

Możliwy scenariusz:

```text
plan bez zmian
+
workload x10
+
blocking
=
wzrost duration
```

To nie jest plan regression.

---

# 9. Compare plans

Przy wielu planach pytaj:

- który plan był używany w dobrym okresie?
- który w złym?
- czy zmieniła się cardinality estimation?
- czy zmienił się join type?
- czy pojawił się scan?
- czy zmienił się DOP?
- czy zmienił się memory grant?
- czy pojawił się spill?
- czy problem zależy od parametrów?

Powiązany moduł:

- [Query Performance](../query-performance/)

---

# 10. Query Store wait stats

W repo dla wariantu VLDB znajduje się konfiguracja:

```text
WAIT_STATS_CAPTURE_MODE = ON
```

Źródło:

- [20_querystore_vldb.sql](../../docs/VLDB_Survival_Kit_SQLServer_2022/SCRIPTS/TSQL/20_querystore_vldb.sql)

To pozwala powiązać historyczne zachowanie zapytania z kategoriami waitów.

Jest to szczególnie cenne, gdy:

```text
duration ↑
CPU bez dużej zmiany
```

i chcemy sprawdzić, czy zapytanie zaczęło czekać np. na:

- locks,
- I/O,
- memory,
- CPU,
- parallelism.

Powiązany moduł:

- [Wait Statistics](../wait-statistics/)

---

# 11. Force Plan

Repo ma kilka gotowych przykładów:

```sql
EXEC sys.sp_query_store_force_plan
    @query_id = <QID>,
    @plan_id = <PID>;
```

Źródła:

- [Lab 01 force plan](../../labs/01-query-store-regression/04_force_plan.sql)
- [Lab 06 force plan](../../labs/06-internals/Lab06_QueryStore_ForcePlan_QCR/scripts/03_find_and_force_plan.sql)

Forcing ma sens wtedy, gdy masz **udokumentowaną regresję** i znany plan, który wcześniej działał poprawnie.

---

# 12. Force Plan nie jest końcem analizy

Plan forcing może być świetnym działaniem stabilizującym, ale często jest:

```text
mitigation
```

a nie:

```text
permanent root-cause fix
```

Po forcingu nadal ustal:

- dlaczego plan się zmienił?
- statystyki?
- parameter sensitivity?
- compatibility level?
- zmiana danych?
- indeks?
- zmiana kodu?

---

# 13. Unforce / rollback

Repo w QS Compat Report jawnie uwzględnia rollback:

```sql
EXEC sys.sp_query_store_unforce_plan
    @query_id = <id>,
    @plan_id = <id>;
```

Źródło:

- [QS Compat Report](../../scripts/t-sql/database/QS-Compat-Report/QS_Compat_Report.sql)

Każdy forcing powinien mieć zapisane:

```text
query_id
plan_id
reason
timestamp
owner
expected effect
validation window
rollback criteria
```

---

# 14. Force failures

Po forcingu sprawdź status planu.

Repo w Lab 06 wskazuje m.in.:

```text
is_forced_plan
force_failure_count
```

Nie zakładaj, że samo wykonanie `sp_query_store_force_plan` oznacza trwały sukces.

Monitoruj, czy forcing faktycznie jest stosowany.

---

# 15. Query Store Hints

SQL Server 2022+ pozwala zastosować hint do query bez zmiany kodu aplikacji.

Repo ma osobny lab:

- [Query Store Hints](../../labs/06-internals/Lab09_QueryStore_Hints_SQL2022/)

Przykładowe zastosowania labu obejmują m.in.:

- MAXDOP,
- `USE HINT ('DISABLE_OPTIMIZER_ROWGOAL')`,
- query optimizer compatibility hints.

Traktuj Query Store Hint jak **kontrolowaną interwencję operacyjną**.

Zapisuj:

- dlaczego został dodany,
- kto go dodał,
- oczekiwany efekt,
- sposób usunięcia,
- wynik walidacji.

---

# 16. Force Plan vs Query Store Hint

Uproszczony wybór:

```text
Known good historical plan?
        |
       YES
        |
        v
Consider Force Plan

Need behavior change without code change?
        |
       YES
        |
        v
Consider Query Store Hint
```

To nie jest automatyczny algorytm.

Przed decyzją analizuj plan, runtime stats i przyczynę regresji.

---

# 17. Compatibility level changes

Repo ma specjalny pakiet:

- [QS Compat Report](../../scripts/t-sql/database/QS-Compat-Report/)

Jego celem jest porównanie Query Store:

```text
BEFORE
compatibility level 130

vs

AFTER
compatibility level 160
```

Raport pomaga:

- porównać duration,
- CPU,
- logical reads,
- wykryć regresje,
- znaleźć wcześniejszy plan,
- rozważyć forcing.

To jest dobry wzorzec dla każdej większej zmiany środowiska:

```text
baseline
→ controlled change
→ compare
→ mitigate if needed
```

---

# 18. Query Store i parameter sensitivity

Jeżeli query ma kilka bardzo różnych profili parametrów, jeden historycznie dobry plan może nie być dobry dla wszystkich przypadków.

Sprawdź:

- liczbę planów,
- rozkład runtime,
- parametry,
- powtarzalność regresji.

Repo Lab 06 celowo pokazuje scenariusz parameter sensitivity/sniffing.

Nie używaj force plan jako automatycznej odpowiedzi na każdy problem z parametrami.

---

# 19. Query Store configuration

Repo zawiera także konfigurację dla VLDB:

- [Query Store VLDB Runbook](../../docs/VLDB_Survival_Kit_SQLServer_2022/RUNBOOKS/QueryStore-VLDB.md)

oraz przykład:

```text
QUERY_CAPTURE_MODE = AUTO
WAIT_STATS_CAPTURE_MODE = ON
CLEANUP_POLICY
DATA_FLUSH_INTERVAL_SECONDS
```

Konfiguracja musi uwzględniać:

- charakter workloadu,
- rozmiar bazy,
- retencję,
- liczbę ad-hoc queries,
- dostępne miejsce,
- wymagania diagnostyczne.

Nie kopiuj ustawień VLDB mechanicznie do każdej bazy.

---

# 20. Query Store capacity / retention

Query Store jest źródłem historii tylko wtedy, gdy dane są utrzymywane wystarczająco długo.

Sprawdź:

- `current_storage_size_mb`,
- `max_storage_size_mb`,
- cleanup policy,
- capture mode,
- retention.

Jeżeli incydent wydarzył się tydzień temu, ale retencja danych już go nie obejmuje, Query Store nie odtworzy historii.

---

# 21. Evidence to collect

Minimalny zestaw do incydentu:

```text
Database:
Incident window:
Baseline window:

Query Store state:
Capture mode:
Wait stats capture:
Storage usage:

query_id:
query_hash:

plan_id BEFORE:
plan_id INCIDENT:

Execution count BEFORE / INCIDENT:
Avg duration BEFORE / INCIDENT:
Avg CPU BEFORE / INCIDENT:
Avg logical reads BEFORE / INCIDENT:

Wait profile:
Plan differences:
Recent deployment/change:
Compatibility level:
Statistics update:
Index change:

Forced plan:
Query Store Hint:
Validation result:
Rollback criteria:
```

---

# 22. Validation after intervention

Po force plan / hint / tuning porównaj:

- avg duration,
- avg CPU,
- logical reads,
- execution count,
- wait profile,
- application latency,
- plan stability.

Nie wystarczy:

```text
query executed once and was fast
```

Potrzebujesz reprezentatywnego okna workloadu.

Repo ma gotowy przykład:

- [Forced vs unforced test](../../labs/06-internals/Lab06_QueryStore_ForcePlan_QCR/scripts/04_test_forced_vs_unforced.sql)

---

# 23. Czego nie robić

## Nie force'uj planu tylko dlatego, że ma najniższe avg_duration

Sprawdź liczbę wykonań, parametry, CPU, reads i reprezentatywność okresu.

## Nie traktuj forcingu jako permanentnego rozwiązania bez dalszej analizy

Najpierw stabilizacja, potem root cause.

## Nie porównuj nieporównywalnych okien workloadu

Peak vs noc może dać fałszywy obraz regresji.

## Nie czyść Query Store podczas incydentu

Możesz usunąć najważniejszy materiał dowodowy.

## Nie zakładaj, że Query Store ma kompletne dane

Sprawdź state, capture mode, retention i storage.

## Nie ignoruj force failures

Sprawdź `force_failure_count`.

## Nie stosuj Query Store Hint bez planu rollback

To jest zmiana zachowania optymalizatora dla konkretnego query.

---

# 24. Related troubleshooting

- [Query Performance](../query-performance/)
- [Wait Statistics](../wait-statistics/)
- [CPU](../cpu/)
- [I/O](../io/)
- [Memory](../memory/)
- [Blocking](../blocking/)

---

# TL;DR

```text
Query slowed down
      |
      v
Define BEFORE and INCIDENT windows
      |
      v
Find query_id
      |
      v
Compare runtime stats
      |
      v
Compare plan_id
      |
      v
CPU / reads / waits / duration
      |
      v
Plan regression?
      |
      +------ no ------> investigate workload/resource
      |
     yes
      |
      v
Known good plan?
      |
      v
Force plan / controlled mitigation
      |
      v
Validate under real workload
      |
      v
Find root cause
      |
      v
Keep / unforce / replace with permanent fix
```
