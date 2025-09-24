# SQL Server Buffer Pool – Definicje i Wyjaśnienia

## Buffer Pool
Buffer Pool (data cache) to największy obszar pamięci SQL Server.  
Przechowuje **strony danych** i **indeksów** (każda 8 KB) pobrane z plików baz danych.  
Dzięki temu większość zapytań działa na danych w pamięci zamiast czytać z dysku.

### Co znajduje się w Buffer Pool:
- **DATA_PAGE** – strony z wierszami tabel.
- **INDEX_PAGE** – strony węzłów drzew B-Tree (indeksy).
- **IAM_PAGE** – *Index Allocation Map*, opisuje alokację extentów.
- **PFS, GAM, SGAM** – metadane zarządzania stronami:
  - *PFS* (Page Free Space) – ile miejsca wolnego na stronach.
  - *GAM* (Global Allocation Map) – które extenty są wolne.
  - *SGAM* (Shared Global Allocation Map) – extenty współdzielone.
- **Dirty Pages** – zmodyfikowane strony oczekujące na zapis (checkpoint/lazy writer).
- **Free Pages** – wolne sloty, gotowe do użycia.

Nie znajdują się tam:
- Plany zapytań (trzymane w **plan cache**).
- Pamięć robocza na sorty/hash joiny (to inne clerks).

---

## Memory Clerks
**Memory Clerks** to wewnętrzne komponenty SQL Server, które zarządzają różnymi obszarami pamięci.  
Każdy clerk raportuje ile pamięci posiada i na co jest używana.

Najważniejsze:
- **MEMORYCLERK_SQLBUFFERPOOL** – buffer pool (dane i indeksy).
- **CACHESTORE_SQLCP** – plany ad-hoc (compiled plans).
- **CACHESTORE_OBJCP** – plany procedur i funkcji.
- **MEMORYCLERK_SQLLOGPOOL** – bufor logu transakcyjnego.
- **MEMORYCLERK_SQLQUERYEXEC** – pamięć przyznawana zapytaniom (np. hash join).
- **MEMORYCLERK_SQLCLR** – pamięć dla SQL CLR.
- **MEMORYCLERK_SQLGENERAL** – struktury ogólne i metadane.

Zapytanie diagnostyczne:
```sql
SELECT TOP(20)
    mc.name, mc.type,
    SUM(mc.pages_kb)/1024.0 AS MB
FROM sys.dm_os_memory_clerks mc
GROUP BY mc.name, mc.type
ORDER BY MB DESC;
```

---

## Page Life Expectancy (PLE)
**Page Life Expectancy** (PLE) mierzy ile sekund średnio strona danych pozostaje w buffer pool zanim zostanie usunięta.  
Jest liczony **per NUMA node**.

Interpretacja:
- **Wysokie PLE** – stabilny buffer pool, strony trzymane długo w pamięci.
- **Niskie PLE** – częste wyrzucanie stron → możliwy brak RAM lub bardzo intensywne workloady.

Historycznie próg ostrzegawczy: **300 sekund**, ale dziś zależy to od wielkości serwera:
- małe serwery (kilka GB RAM) – naturalnie niższe PLE,
- duże serwery (setki GB RAM) – PLE powinien być wielokrotnie wyższy.

Zapytanie:
```sql
SELECT
    instance_name AS NUMA_Node,
    cntr_value    AS PageLifeExpectancy_seconds
FROM sys.dm_os_performance_counters
WHERE counter_name = 'Page life expectancy';
```

---

## Podsumowanie
- **Buffer Pool** = magazyn stron danych w pamięci (serce SQL Server).
- **Memory Clerks** = szczegółowe rozbicie pamięci na obszary i komponenty.
- **Page Life Expectancy** = zdrowotny wskaźnik długości życia stron w buffer pool.

👉 Do pełnej analizy używaj skryptu: `BufferPool_Audit.sql`
