# Troubleshooting: CPU

Wysokie CPU samo w sobie nie jest diagnozą.

Najpierw trzeba odpowiedzieć na kilka osobnych pytań:

1. Czy host rzeczywiście ma presję CPU?
2. Czy CPU zużywa SQL Server czy inne procesy?
3. Ile schedulerów SQL Server faktycznie może używać?
4. Czy schedulery mają kolejkę runnable?
5. Czy workload SQL zużywa CPU efektywnie, czy mamy regresję zapytań?
6. Które zapytania i które bazy odpowiadają za największy udział CPU?

---

# Diagnostic flow

```text
CPU alert / slow application
          |
          v
Host CPU pressure?
          |
    +-----+-----+
    |           |
   NO          YES
    |           |
    |      SQL Server CPU?
    |           |
    |      +----+----+
    |      |         |
    |     NO        YES
    |      |         |
    |   other      scheduler
    |   process    pressure?
    |                |
    |           runnable queue
    |           SOS_SCHEDULER_YIELD
    |                |
    |                v
    |          top CPU workload
    |                |
    |          database / query
    |                |
    |          execution plan
    |                |
    +--------------> root cause
                     |
                     v
                  validate
```

---

# 1. Symptoms

Typowe sygnały:

- wysoki CPU na hoście,
- wzrost czasu odpowiedzi aplikacji,
- większa liczba runnable tasks,
- wzrost signal waits,
- wzrost `SOS_SCHEDULER_YIELD`,
- nagły wzrost CPU jednej bazy,
- regresja pojedynczych zapytań,
- throughput przestaje rosnąć mimo wzrostu obciążenia,
- workerzy długo czekają na scheduler.

Nie każdy przypadek wysokiego CPU oznacza problem.

Jeżeli workload wzrósł, throughput również wzrósł, kolejki schedulerów są niskie, a SLA jest spełnione, wysokie wykorzystanie CPU może oznaczać po prostu wykorzystanie dostępnej pojemności.

---

# 2. First checks

W tej kolejności:

1. Sprawdź CPU hosta.
2. Rozdziel CPU SQL Server i pozostałych procesów.
3. Sprawdź liczbę CPU widocznych przez host.
4. Sprawdź liczbę schedulerów `VISIBLE ONLINE`.
5. Sprawdź runnable queue.
6. Sprawdź `SOS_SCHEDULER_YIELD` i signal wait.
7. Sprawdź aktualnie CPU-intensive requesty.
8. Sprawdź historyczne zapytania w Query Store.
9. Sprawdź CPU per baza.
10. Dopiero potem analizuj konkretne plany i kod.

---

# 3. CPU hosta != CPU dostępne dla SQL Server

Repo zawiera:

- [sqlmaniak_cpu_health.sql](../../scripts/zabbix-mssql-monitoring/custom-queries/sqlmaniak_cpu_health.sql)

Skrypt zwraca m.in.:

```text
host_logical_cpu_count
configured_scheduler_count
sql_visible_online_schedulers
active_schedulers
runnable_tasks_total
runnable_tasks_per_active_scheduler
current_tasks_total
active_workers_total
work_queue_total
sos_waiting_tasks_count
sos_wait_time_ms
sos_signal_wait_time_ms
sql_process_cpu_pct_host
system_idle_pct
other_processes_cpu_pct
```

To jest podstawowy punkt startowy dla CPU troubleshooting.

## Dlaczego liczba schedulerów ma znaczenie

Host może mieć więcej logicznych CPU niż SQL Server faktycznie używa.

Dlatego procent CPU hosta bez informacji o schedulerach SQL Server może prowadzić do błędnych wniosków.

Przykładowo:

```text
host: 24 logical CPU
SQL Server: 12 VISIBLE ONLINE schedulers
```

SQL Server może wykorzystać całą swoją dostępną pojemność schedulerów, a host nadal nie będzie pokazywał 100% CPU.

Dlatego diagnoza CPU powinna uwzględniać:

```text
host CPU
+
SQL process CPU
+
VISIBLE ONLINE schedulers
+
runnable queue
```

a nie tylko jeden procent.

---

# 4. SQL Server czy inne procesy?

`sqlmaniak_cpu_health.sql` rozdziela:

```text
sql_process_cpu_pct_host
other_processes_cpu_pct
system_idle_pct
```

Jeżeli wysokie CPU generuje inny proces, strojenie zapytań SQL może nie zmienić sytuacji.

Przykładowe źródła poza SQL Server:

- antivirus,
- backup agent,
- monitoring,
- inne usługi,
- proces ETL,
- narzędzia administracyjne,
- procesy systemowe.

Najpierw ustal **kto zużywa CPU**.

---

# 5. Scheduler pressure

Najważniejszym sygnałem nie jest sam procent CPU, ale to, czy workery SQL czekają na dostęp do schedulera.

Repo zbiera:

```text
runnable_tasks_total
runnable_tasks_per_active_scheduler
```

z:

```sql
sys.dm_os_schedulers
```

dla schedulerów:

```text
VISIBLE ONLINE
```

## Interpretacja

```text
RUNNING
  worker aktualnie wykonuje kod na CPU

RUNNABLE
  worker jest gotowy do pracy,
  ale czeka na scheduler / CPU
```

Jeżeli runnable queue rośnie i utrzymuje się, mamy znacznie mocniejszy sygnał presji CPU niż sam wysoki procent wykorzystania procesora.

Nie oceniaj jednak pojedynczego snapshotu. Szukaj utrzymującego się trendu i korelacji z pogorszeniem czasu odpowiedzi.

---

# 6. SOS_SCHEDULER_YIELD

Repo zbiera również:

```text
sos_waiting_tasks_count
sos_wait_time_ms
sos_signal_wait_time_ms
```

dla:

```text
SOS_SCHEDULER_YIELD
```

Wzrost tego waitu może być zgodny z workloadem intensywnie korzystającym z CPU, ale sam wait nie wystarcza do diagnozy.

Koreluj go z:

- runnable queue,
- SQL process CPU,
- throughput,
- top CPU queries,
- execution plans,
- zmianami workloadu.

---

# 7. CPU per baza

Repo ma dwa istniejące źródła.

## Monitoring Zabbix

- [sqlmaniak_db_cpu.sql](../../scripts/zabbix-mssql-monitoring/custom-queries/sqlmaniak_db_cpu.sql)

Zapytanie korzysta z:

```text
sys.dm_exec_query_stats
+
sys.dm_exec_plan_attributes
+
dbid
```

i agreguje `total_worker_time` per baza.

Monitoring rozwija to dalej do metryk:

```text
mssql.db.cpu_time_ms.delta
mssql.db.cpu_ms_per_sec
mssql.db.cpu_share_pct
mssql.db.cpu_capacity_pct
```

Dokumentacja:

- [Alerty i CPU per baza](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)

## Prosty raport ad hoc

- [dbpercpu.sql](../../scripts/t-sql/database/dbpercpu.sql)

---

# 8. Ważne ograniczenie CPU per baza

Atrybucja CPU per baza jest oparta na plan cache.

Dokumentacja modułu DBACentralRepository opisuje to jawnie:

- [PERF_MODULE.md](../../scripts/DBACentralRepository_v3/PERF_MODULE.md)

Źródłem jest:

```text
sys.dm_exec_query_stats
+
plan attribute dbid
```

To oznacza, że wyniki są zależne od aktualnego plan cache.

Restart instancji, eviction planu lub recompilacja może spowodować reset/spadek wartości.

Dlatego:

> CPU per baza traktuj jako atrybucję workloadu i trend, a nie jako księgowość CPU gwarantującą 100% przypisania każdego cyklu procesora.

---

# 9. Które zapytania zużywają CPU?

Po potwierdzeniu presji CPU przejdź niżej.

Dla bieżących requestów sprawdzaj przede wszystkim:

- `cpu_time`,
- `total_elapsed_time`,
- reads,
- writes,
- wait_type,
- dop,
- tekst zapytania,
- plan.

Dla historii wykorzystaj Query Store.

Repo zawiera:

- [Request PerfPack](../../scripts/t-sql/Reques_PerfPack/)
- [01_QueryStore_FindQueries.sql](../../scripts/t-sql/Reques_PerfPack/01_QueryStore_FindQueries.sql)
- [02_PlanCache_Fallback.sql](../../scripts/t-sql/Reques_PerfPack/02_PlanCache_Fallback.sql)

Query Store pozwala porównywać m.in.:

```text
avg_cpu_time
duration
logical reads
plan_id
query_id
```

---

# 10. CPU time vs elapsed time

Przy analizie zapytania rozróżniaj:

```text
CPU time
```

od:

```text
elapsed time
```

Zapytanie może mieć:

```text
elapsed = 30 s
CPU = 500 ms
```

i być przede wszystkim problemem oczekiwania.

Może też mieć:

```text
elapsed = 5 s
CPU = 18 s
```

przy execution planie wykorzystującym wielu workerów równolegle.

Dlatego sama długość zapytania nie mówi, że jest ono CPU-bound.

---

# 11. Execution plan

Po znalezieniu kosztownego zapytania analizuj plan.

Szukaj m.in.:

- dużej liczby przetwarzanych wierszy,
- scans,
- nieefektywnych joinów,
- złej estymacji cardinality,
- drogich scalar expressions,
- funkcji wykonywanych per row,
- sortów/agregacji,
- niepotrzebnego parallelism,
- zbyt wysokiego DOP dla charakteru workloadu,
- regresji planu,
- parameter sniffing / parameter sensitivity.

Nie zaczynaj od zmiany `MAXDOP`.

Najpierw ustal, dlaczego konkretny workload zużywa CPU.

---

# 12. Najczęstsze klasy root cause

## Query regression

Po deployment, zmianie statystyk, zmianie compatibility level lub zmianie danych zapytanie może dostać gorszy plan.

Sprawdź Query Store.

---

## Missing / ineffective index

Duża liczba odczytywanych i przetwarzanych wierszy może zwiększyć CPU.

Indeks jest rozwiązaniem tylko wtedy, gdy zmienia access path w sposób potwierdzony planem i pomiarem.

---

## Cardinality estimation

Zła estymacja może prowadzić do:

- niewłaściwego join type,
- złej kolejności joinów,
- niewłaściwego DOP,
- nadmiernej pracy operatorów.

---

## Parameter sensitivity

Różne parametry mogą potrzebować różnych planów.

Nie zakładaj od razu, że rozwiązaniem jest `OPTION (RECOMPILE)`.

Najpierw porównaj plany i runtime statistics.

---

## Excessive parallelism

Parallelism może zwiększyć wykorzystanie wielu schedulerów.

Ale:

> parallelism nie jest automatycznie problemem tylko dlatego, że CPU jest wysokie.

Sprawdź throughput, elapsed time, CPU time i presję schedulerów.

---

## Compilation / recompilation

Duża liczba kompilacji może zużywać znaczną część CPU.

Repo zawiera dokumentację:

- [Plan Cache](../../docs/PlanCache/README.md)

Nie używaj globalnego:

```sql
DBCC FREEPROCCACHE;
```

jako „naprawy CPU”.

Może to spowodować dodatkowy skok kompilacji, CPU i latency.

---

## External CPU pressure

Jeżeli:

```text
other_processes_cpu_pct
```

rośnie, problem może być poza SQL Server.

---

# 13. CPU i waits

CPU troubleshooting nie powinien być prowadzony bez waits.

Przydatne źródło:

- [DBA Daily Pack – waits baseline/delta](../../tools/DBADaillyPack/sql/05_Waits_Baseline_And_Delta.sql)

Nie patrz tylko na cumulative waits od startu instancji.

Preferuj:

```text
snapshot
   ↓
delta
   ↓
problem window
```

i koreluj z CPU.

---

# 14. Monitoring zamiast arbitralnego progu

Dokumentacja Zabbixa w repo celowo nie aktywuje prostego alertu:

```text
CPU > X%
```

jako jedynej definicji problemu.

Dostępne są:

- względne CPU,
- runnable tasks,
- `SOS_SCHEDULER_YIELD`,
- E2E,
- CPU innych procesów,
- CPU per baza.

Źródło:

- [Alerty per instancja i CPU](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)

Docelowa logika alertu powinna korelować kilka sygnałów.

Przykładowy model:

```text
SQL CPU high
AND
runnable queue elevated
AND/OR
SOS_SCHEDULER_YIELD elevated
AND
E2E / application latency degraded
```

Progi powinny być dostrojone do baseline konkretnej instancji.

---

# 15. Evidence to collect

Minimalny zestaw do incydentu CPU:

```text
Timestamp / incident window:

Host logical CPU:
SQL visible online schedulers:

Host CPU:
SQL Server CPU:
Other processes CPU:
System idle:

Runnable tasks total:
Runnable tasks per scheduler:
Work queue:
Active workers:

SOS_SCHEDULER_YIELD delta:
Signal wait delta:

Top active requests by CPU:
Top historical queries by CPU:
Top database CPU share:

Query Store query_id / plan_id:
Execution plan:
Recent deployment/change:
Compatibility level:
MAXDOP:
Cost threshold:
Business impact:
```

---

# 16. Validation

Po zmianie porównaj:

- SQL process CPU,
- runnable queue,
- runnable tasks per scheduler,
- signal waits,
- `SOS_SCHEDULER_YIELD`,
- query CPU,
- elapsed time,
- logical reads,
- throughput,
- E2E/application latency.

Nie uznawaj poprawki za sukces tylko dlatego, że CPU spadło.

Przykład złej „optymalizacji”:

```text
before:
CPU 90%
1000 requests/s

after:
CPU 50%
400 requests/s
```

CPU spadło, ale system wykonuje mniej pracy.

Interesuje nas efektywność i SLA, nie najniższy możliwy procent CPU.

---

# 17. Czego nie robić

## Nie diagnozuj na podstawie CPU > 80%

Bez kontekstu schedulerów i workloadu ta liczba może być myląca.

## Nie zmieniaj MAXDOP jako pierwszej reakcji

Najpierw znajdź workload i plan.

## Nie czyść całego plan cache

Może to zwiększyć CPU przez falę rekompilacji.

## Nie optymalizuj tylko najdłuższego zapytania

Najdłuższe elapsed time nie musi oznaczać największego CPU.

## Nie ignoruj innych procesów

SQL Server może wcale nie być źródłem presji CPU.

## Nie używaj tylko cumulative counters

Korelacja z oknem incydentu i delty są ważniejsze.

## Nie traktuj CPU per baza jako absolutnej księgowości

To atrybucja oparta na plan cache.

---

# 18. Related areas

- [Query Performance](../query-performance/)
- [Memory](../memory/)
- [I/O](../io/)
- [Blocking](../blocking/)

## Existing sources of truth

- [CPU health collector](../../scripts/zabbix-mssql-monitoring/custom-queries/sqlmaniak_cpu_health.sql)
- [CPU per database collector](../../scripts/zabbix-mssql-monitoring/custom-queries/sqlmaniak_db_cpu.sql)
- [CPU monitoring documentation](../../scripts/zabbix-mssql-monitoring/docs/excel-mapping/03-alerts-and-cpu.md)
- [DB CPU ad hoc](../../scripts/t-sql/database/dbpercpu.sql)
- [DBACentralRepository PERF](../../scripts/DBACentralRepository_v3/PERF_MODULE.md)
- [DBA Daily Pack](../../tools/DBADaillyPack/)
- [Request PerfPack](../../scripts/t-sql/Reques_PerfPack/)
- [Plan Cache](../../docs/PlanCache/)

---

# TL;DR

```text
High CPU
   |
   v
Host really CPU constrained?
   |
   v
SQL or other processes?
   |
   v
How many schedulers can SQL use?
   |
   v
Runnable queue?
   |
   v
SOS_SCHEDULER_YIELD / signal waits?
   |
   v
Which database?
   |
   v
Which query?
   |
   v
Which plan / root cause?
   |
   v
Fix
   |
   v
Compare CPU + throughput + latency
```
