# Troubleshooting: Wait Statistics

Wait statistics są **mapą czasu oczekiwania SQL Server**, a nie gotową diagnozą.

Najważniejsze pytanie nie brzmi:

> Jaki wait jest najwyżej?

Tylko:

> **Na co SQL Server czekał w interesującym nas oknie czasu i co to mówi o workloadzie?**

---

# Diagnostic flow

```text
Slow system / incident
        |
        v
Define problem window
        |
        v
Capture wait baseline
        |
        v
Capture second snapshot
        |
        v
Calculate DELTA
        |
        v
Filter benign/background waits
        |
        v
Group by category
        |
        v
Identify dominant waits
        |
        v
Correlate with:
CPU / I/O / locks / memory / network / parallelism / log
        |
        v
Find workload / query / resource
        |
        v
Root cause
        |
        v
Validate with another delta
```

---

# 1. Najważniejsza zasada: DELTA

`sys.dm_os_wait_stats` zawiera wartości skumulowane od ostatniego resetu statystyk lub restartu instancji.

Dlatego wynik:

```sql
SELECT *
FROM sys.dm_os_wait_stats;
```

nie odpowiada automatycznie na pytanie:

> Co wydarzyło się podczas incydentu od 14:00 do 14:15?

Repo zawiera dwa podejścia oparte na snapshotach.

## DBA Daily Pack

- [05_Waits_Baseline_And_Delta.sql](../../tools/DBADaillyPack/sql/05_Waits_Baseline_And_Delta.sql)

Skrypt:

1. zapisuje bieżący stan,
2. znajduje poprzedni snapshot,
3. liczy delty:
   - waiting tasks,
   - wait time,
   - signal wait time,
4. pokazuje średni wait per task.

## Wait Stats Clinic

- [Wait Stats Clinic](../../labs/06-internals/Lab05_Wait_Stats_Clinic/)
- [snapshot start](../../labs/06-internals/Lab05_Wait_Stats_Clinic/scripts/01_snapshot_start.sql)
- [snapshot end + delta](../../labs/06-internals/Lab05_Wait_Stats_Clinic/scripts/03_snapshot_end_and_delta.sql)

Lab celowo nie czyści globalnych waitów. Porównuje dwa snapshoty.

---

# 2. Nie resetuj wait stats tylko po to, żeby diagnozować

Polecenie:

```sql
DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
```

usuwa historię skumulowanych waitów.

W laboratorium może być przydatne, ale w produkcji zazwyczaj lepiej:

```text
snapshot A
   ↓
problem window
   ↓
snapshot B
   ↓
B - A
```

Dzięki temu:

- nie tracisz danych historycznych,
- możesz porównać konkretne okno,
- monitoring może nadal korzystać z cumulative counters.

---

# 3. Wait time = resource + signal

Repo zawiera wrapper:

- [dba.usp_waits](../../labs/08-dmv/scripts/per_certificate/05b_wrapper_dba.usp_waits.sql)

który liczy:

```text
wait_time_ms
signal_wait_time_ms
resource_wait_time_ms =
    wait_time_ms - signal_wait_time_ms
```

To rozróżnienie jest bardzo ważne.

## Resource wait

Worker czeka na zasób, np.:

- lock,
- strona z storage,
- flush logu,
- memory grant,
- network.

## Signal wait

Zasób jest już dostępny, ale worker czeka na możliwość wykonania na schedulerze.

Podwyższony udział signal waits może wskazywać na presję schedulerów/CPU, ale zawsze trzeba korelować go z CPU i runnable queue.

Powiązany moduł:

- [CPU](../cpu/)

---

# 4. Filtruj background / benign waits

Nie wszystkie wait types reprezentują problem użytkownika.

Repo filtruje m.in. takie oczekiwania jak:

```text
SLEEP_TASK
SLEEP_SYSTEMTASK
LAZYWRITER_SLEEP
BROKER_TASK_STOP
BROKER_TO_FLUSH
XE_TIMER_EVENT
XE_DISPATCHER_WAIT
REQUEST_FOR_DEADLOCK_SEARCH
LOGMGR_QUEUE
CHECKPOINT_QUEUE
DIRTY_PAGE_POLL
```

Źródła:

- [DBA Daily Pack waits](../../tools/DBADaillyPack/sql/05_Waits_Baseline_And_Delta.sql)
- [Wait Stats Clinic delta](../../labs/06-internals/Lab05_Wait_Stats_Clinic/scripts/03_snapshot_end_and_delta.sql)

Lista filtrów nie jest uniwersalną prawdą dla wszystkich środowisk. Powinna być traktowana jako praktyczny punkt startowy.

---

# 5. Kategorie waitów

Repo zawiera gotowy wrapper:

- [dba.usp_top_waits_categories](../../labs/08-dmv/scripts/per_certificate/05m_wrapper_dba.usp_top_waits_categories.sql)

który mapuje waity m.in. do:

```text
LOCKS
LATCH
LATCH_PAGE
IO_PAGEIOLATCH
LOG
IO_OTHER
NETWORK
MEMORY
CPU/SCHEDULER
HADR/ALWAYS ON
PARALLELISM
OTHER
```

To jest bardzo przydatne do pierwszego triage.

## Ważne

Kategoria jest heurystyką.

Nie kończ diagnozy na:

```text
Top category = IO
```

Idź dalej do konkretnego wait type, resource i workloadu.

---

# 6. Najważniejsze grupy

## Locks

Typowe:

```text
LCK_M_S
LCK_M_U
LCK_M_X
LCK_M_IS
LCK_M_IX
```

Pytania:

- kto blokuje?
- jak długo trwa transakcja?
- jaki jest head blocker?
- jaki obiekt/indeks?
- jaki isolation level?
- czy problemem jest access order lub zakres DML?

Powiązane:

- [Blocking](../blocking/)
- [Deadlocks](../deadlocks/)

---

## PAGEIOLATCH_*

Przykłady:

```text
PAGEIOLATCH_SH
PAGEIOLATCH_EX
PAGEIOLATCH_UP
```

Oznaczają oczekiwanie związane z pobraniem strony danych do pamięci.

Nie oznaczają automatycznie:

> storage jest wolny.

Sprawdź również:

- czy workload czyta bardzo dużo stron,
- execution plan,
- indeksy,
- cache hit / memory pressure,
- latencję plików,
- czy problem pojawił się po zmianie planu.

Powiązane:

- [I/O](../io/)
- [Memory](../memory/)
- [Query Performance](../query-performance/)

---

## WRITELOG

Worker czeka na flush logu transakcyjnego.

Sprawdź:

- write latency pliku log,
- log flush throughput,
- rozmiar transakcji,
- liczbę commitów,
- storage logu,
- autogrowth,
- synchroniczne HA, jeśli dotyczy.

Nie zakładaj, że jedynym rozwiązaniem jest szybszy dysk.

Duża liczba bardzo małych transakcji może generować ogromną liczbę flushów.

---

## SOS_SCHEDULER_YIELD

Silnie związany z aktywnością CPU/schedulerów.

Koreluj z:

- SQL process CPU,
- runnable tasks,
- signal waits,
- top CPU queries,
- throughput.

Powiązane:

- [CPU](../cpu/)

Nie interpretuj go jako samodzielnego dowodu, że „CPU jest za mało”.

---

## RESOURCE_SEMAPHORE

Typowo związany z oczekiwaniem na query memory grant.

Sprawdź:

- aktywne grants,
- requested vs granted memory,
- plany,
- cardinality estimation,
- concurrency,
- sort/hash operators.

Repo:

- [Memory Internals](../../docs/MemoryInternals/README.md)
- [Waits_Memory_Pressure.sql](../../docs/MemoryInternals/scripts/Waits_Memory_Pressure.sql)

Powiązany moduł:

- [Memory](../memory/)

---

## PAGELATCH_*

To nie jest to samo co PAGEIOLATCH.

```text
PAGEIOLATCH
```

wiąże się z fizycznym I/O strony.

```text
PAGELATCH
```

dotyczy synchronizacji strony znajdującej się już w pamięci.

Przy PAGELATCH sprawdzaj m.in.:

- TempDB allocation contention,
- hot page,
- last-page insert contention,
- wzorzec współbieżnego dostępu.

Powiązane:

- [TempDB](../tempdb/)

---

## ASYNC_NETWORK_IO

SQL Server czeka, aż klient odbierze dane.

Możliwe przyczyny:

- aplikacja wolno konsumuje result set,
- sieć,
- zbyt duży result set,
- klient wykonuje pracę pomiędzy odczytami,
- aplikacja nie pobiera danych wystarczająco szybko.

Nie oznacza automatycznie awarii sieci.

Sprawdź:

- ilość zwracanych danych,
- zachowanie aplikacji,
- elapsed time,
- network throughput,
- row count.

---

## CXPACKET / CXCONSUMER

Dotyczą współpracy workerów w planie równoległym.

Nie interpretuj ich automatycznie jako:

> MAXDOP jest za wysoki.

Sprawdź:

- execution plan,
- rozkład pracy między workerami,
- cardinality,
- koszt zapytania,
- CPU,
- elapsed time,
- skew.

---

## THREADPOOL

Oczekiwanie na worker thread jest sygnałem wymagającym szybkiej uwagi.

Może być związane m.in. z:

- bardzo dużą liczbą równoległych requestów,
- długim blockingiem zajmującym workery,
- wysokim parallelism,
- przeciążeniem workloadu.

Sprawdź scheduler/workers i blocking zanim zaczniesz zmieniać `max worker threads`.

---

# 7. Average wait per task

DBA Daily Pack liczy:

```text
AvgWaitMsPerTask =
DeltaWaitMs / DeltaWaitingTasks
```

To pomaga rozróżnić:

```text
1 000 000 krótkich waitów
```

od:

```text
100 bardzo długich waitów
```

Sama suma czasu nie wystarcza.

Analizuj razem:

- total wait time,
- waiting tasks count,
- average wait,
- procent całkowitego czasu waitów.

---

# 8. Instance waits vs session/query waits

`sys.dm_os_wait_stats` jest statystyką poziomu instancji.

Repo jawnie zaznacza to również w:

- [DBACentralRepository PERF](../../scripts/DBACentralRepository_v3/PERF_MODULE.md)

Nie przypisuj globalnych wait stats bezpośrednio do konkretnej bazy.

Jeżeli potrzebujesz zejść niżej, użyj odpowiedniego kontekstu:

- `sys.dm_exec_requests.wait_type` — bieżący request,
- `sys.dm_os_waiting_tasks` — aktualnie czekające zadania,
- `sys.dm_exec_session_wait_stats` — waity sesji,
- Query Store wait stats — historycznie dla workloadu, jeśli capture jest dostępny.

---

# 9. Waits nie mówią „dlaczego”

Przykład:

```text
PAGEIOLATCH_SH
```

mówi:

> request czekał na stronę danych.

Nie mówi:

> storage jest root cause.

Możliwe scenariusze:

```text
bad plan
   ↓
table scan
   ↓
miliony stron
   ↓
PAGEIOLATCH_SH
```

albo:

```text
normal query
   ↓
niewiele stron
   ↓
bardzo wysoka read latency
   ↓
PAGEIOLATCH_SH
```

Ten sam wait type, dwie zupełnie różne przyczyny.

---

# 10. Korelacja jest ważniejsza niż pojedynczy wait

Dobre troubleshooting wygląda np. tak:

```text
PAGEIOLATCH_SH delta ↑
+
read latency ↑
+
plan bez regresji
+
normalna liczba reads
=
storage path do sprawdzenia
```

albo:

```text
PAGEIOLATCH_SH delta ↑
+
read latency normalna
+
logical/physical reads ↑↑
+
nowy plan
=
query/access path do sprawdzenia
```

Podobnie:

```text
SOS_SCHEDULER_YIELD ↑
+
runnable queue ↑
+
SQL CPU high
=
real CPU scheduler pressure
```

---

# 11. Problem window

Zawsze zapisuj:

```text
From:
To:
Duration:
Deployment/change:
Application impact:
```

Największą wartość mają waits policzone dla okresu, w którym użytkownik rzeczywiście obserwował problem.

Cumulative top waits z ostatnich 40 dni mogą nie mieć żadnego związku z dzisiejszym incydentem.

---

# 12. Baseline

Warto znać normalny profil waitów instancji.

Przykład:

```text
normal weekday 10:00-11:00
vs
incident weekday 10:00-11:00
```

jest znacznie bardziej użyteczny niż:

```text
incident
vs
zero
```

Wait Stats Clinic w repo właśnie promuje model:

```text
snapshot
workload
delta
category
```

---

# 13. Validation

Po zmianie wykonaj kolejny pomiar w porównywalnym oknie.

Porównaj:

- delta wait time,
- waiting task count,
- average wait per task,
- signal vs resource waits,
- throughput,
- application latency,
- CPU,
- I/O,
- blocking.

Nie wystarczy, że dany wait spadnie.

Można „naprawić” jeden wait i przesunąć problem gdzie indziej.

Przykład:

```text
LCK_M_X ↓
ASYNC_NETWORK_IO ↑↑
throughput ↓
```

To nie musi oznaczać poprawy.

---

# 14. Czego nie robić

## Nie analizuj tylko cumulative waits

Mogą reprezentować wiele dni lub tygodni zupełnie różnych workloadów.

## Nie resetuj wait stats bez potrzeby

Tracisz historię i utrudniasz monitoring.

## Nie wybieraj fixu tylko po nazwie wait type

Wait wskazuje miejsce oczekiwania, nie zawsze root cause.

## Nie sumuj wszystkiego bez filtracji

Background waits mogą całkowicie zdominować wynik.

## Nie utożsamiaj PAGEIOLATCH z „wolnym SAN-em”

Najpierw sprawdź workload i liczbę odczytów.

## Nie utożsamiaj CXPACKET z „złym MAXDOP”

Najpierw przeanalizuj plan i rozkład pracy.

## Nie przypisuj globalnych waits do bazy bez dodatkowego kontekstu

`sys.dm_os_wait_stats` jest na poziomie instancji.

---

# 15. Evidence to collect

Minimalny zestaw:

```text
Incident window:
Instance uptime / last restart:

Top wait deltas:
Wait category:
Delta wait ms:
Delta waiting tasks:
Average wait ms/task:
Signal wait ms:
Resource wait ms:

CPU:
Runnable queue:
I/O latency:
Blocking:
Memory grants:
Top active requests:
Query Store evidence:
Recent deployment/change:
Business impact:
```

---

# 16. Existing sources of truth

## Operational

- [DBA Daily Pack – Waits Baseline and Delta](../../tools/DBADaillyPack/sql/05_Waits_Baseline_And_Delta.sql)

## Lab

- [Wait Stats Clinic](../../labs/06-internals/Lab05_Wait_Stats_Clinic/)
- [Snapshot start](../../labs/06-internals/Lab05_Wait_Stats_Clinic/scripts/01_snapshot_start.sql)
- [Snapshot delta](../../labs/06-internals/Lab05_Wait_Stats_Clinic/scripts/03_snapshot_end_and_delta.sql)

## DMV wrappers

- [dba.usp_waits](../../labs/08-dmv/scripts/per_certificate/05b_wrapper_dba.usp_waits.sql)
- [dba.usp_top_waits_categories](../../labs/08-dmv/scripts/per_certificate/05m_wrapper_dba.usp_top_waits_categories.sql)

## Memory

- [Memory wait diagnostics](../../docs/MemoryInternals/scripts/Waits_Memory_Pressure.sql)

## Stress testing

- [SqlStressLab](../../tools/SqlStressLab/)

---

# 17. Related troubleshooting

- [CPU](../cpu/)
- [I/O](../io/)
- [Memory](../memory/)
- [Blocking](../blocking/)
- [Deadlocks](../deadlocks/)
- [TempDB](../tempdb/)
- [Query Performance](../query-performance/)

---

# TL;DR

```text
Do NOT ask:
"What are my top waits?"

Ask:
"What did SQL Server wait for
during the problem window?"

snapshot A
   |
   v
problem window
   |
   v
snapshot B
   |
   v
DELTA
   |
   v
filter background waits
   |
   v
category
   |
   v
specific wait
   |
   v
correlate with resource/workload
   |
   v
root cause
   |
   v
validate with another delta
```
