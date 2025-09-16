# 🔌 Jak klient łączy się z SQL Server i jak zapytanie jest wykonywane — krok po kroku

Poniżej jest kompletny run-through: od chwili, gdy aplikacja otwiera „połączenie”, aż do momentu, gdy otrzymuje wyniki.

---

## 1. Ogólny szkic przepływu
```
Client App
  └─(Connection string / Driver)─> Network Layer (TCP/TDS)
      └─> SQL Browser / Listener
          └─> SQL Server (Database Engine)
               ├─ Relational Engine (Parser → Optimizer → Execution)
               └─ Storage Engine (Buffer Pool, I/O, Log)
               └─ SQL Agent / Services (opcjonalnie)
      └─(Results)─> Client App
```

---

## 2. Nawiązywanie połączenia — sekwencja zdarzeń

1. **Aplikacja tworzy połączenie**  
   - Używa drivera (ADO.NET, ODBC, JDBC, OLE DB) i *connection string* (np. `Server=myserver;Database=MyDB;Integrated Security=true;`).  
   - Opcje: timeout, encrypt (TLS), Application Name, MultiSubnetFailover, MARS, pooling.

2. **Handshake sieciowy (TDS + transport)**  
   - Protokół TDS (Tabular Data Stream) na TCP (najczęściej) lub Named Pipes/Shared Memory.  
   - Jeśli instancja nazwana → najpierw pytanie do SQL Server Browser (UDP 1434) o port.  
   - Jeśli `Encrypt=True` → start TLS handshake przed uwierzytelnieniem (sygnalizuje certyfikat serwera).

3. **Uwierzytelnienie (Authentication)**  
   - **Windows Authentication**: Kerberos/NTLM; token Windows jest weryfikowany.  
   - **SQL Authentication**: login + password przesyłane bezpiecznie (TLS).  
   - Po sukcesie uwierzytelnienia serwer tworzy *session* (SPID).

4. **Negocjacja sesji i options**  
   - Ustalane są m.in. ANSI settings, DATEFORMAT, language, packet size, isolation level, MARS.  
   - Jeśli connection pooling aktywny, driver zwraca połączenie z puli i wykonuje `sp_reset_connection` by wyczyścić stan sesji.

---

## 3. Jak aplikacja wysyła zapytanie

1. **Prepare / Execute** (dwa typy):
   - **Ad-hoc SQL**: klient wysyła tekst zapytania bez przygotowania.
   - **Prepared statement / parameterized**: klient najpierw *prepare*, potem *execute* z parametrami (może pozwolić na reuse planu).

2. **Parametry / typy danych**:
   - Parametry mają typy (nvarchar, int, datetime...), driver mapuje typy języka aplikacji → SQL.

3. **Przekazanie zapytania do serwera** — zapytanie dociera do Relational Engine.

---

## 4. Relational Engine — co się dzieje przed wykonaniem

1. **Parsing**  
   - Sprawdzenie składni T-SQL. Powstaje parse tree.

2. **Algebraiczny rewrite / bind**  
   - Nazwy obiektów są sprawdzane (czy tabela/kolumna istnieje). Tworzy się bound tree.

3. **Optymalizacja (Query Optimizer)**  
   - Generuje różne plany wykonania (logical → physical), estymuje koszty.  
   - Używa statystyk (histogram, density) by oszacować kardynalność.  
   - Decyzje: join order/type (nested loop/hash/merge), index seek vs scan, parallelism, use of columnstore, etc.

4. **Plan cache / parametr sniffing**  
   - Jeśli plan istnieje w plan cache (dla tego zapytania/pliku/składni) może zostać użyty ponownie.  
   - *Parameter sniffing*: pierwszy zestaw parametrów może wpłynąć na plan (pożądane lub nie).  
   - Możliwe `RECOMPILE`, `OPTION (RECOMPILE)`, `OPTIMIZE FOR`, plan forcing.

5. **Compilation**  
   - Generowany finalny plan wykonywalny (execution plan), wstawiany do cache jeśli przydatne.

---

## 5. Execution Engine — wykonanie planu

1. **Operatorzy planu**  
   - Plan składa się z operatorów (Index Seek, Index Scan, Nested Loops, Hash Match, Sort, Aggregate).  
   - Operatory zwracają rzędy do kolejnych operatorów (iterator model).

2. **Buffer pool i dostęp do stron**  
   - Gdy trzeba strony danych: Storage Engine sprawdza Buffer Pool (RAM). Jeśli brak → robi I/O do plików .mdf/.ndf.  
   - Strony w rozmiarze 8 KB, extenty = 8 stron.

3. **Locki i concurrency**  
   - Podczas dostępu Storage Engine/Lock Manager stosuje locki lub row versioning zależnie od isolation level (READ COMMITTED, SNAPSHOT, SERIALIZABLE...).  
   - Mogą wystąpić blokady (blocking) lub deadlocki; deadlock detector wybiera ofiarę.

4. **Transakcje i log**  
   - Jeżeli polecenie modyfikuje dane → transakcja zapisywana do transaction logu (sekwencyjny append).  
   - Zasada WAL: najpierw zapis do logu, potem zmiany na stronie (durability).  
   - Commit powoduje, że log jest trwały; dalsze flushy do plików mogą przebiegać asynchronicznie, ale log zapewnia przywracalność.

5. **Operacje dodatkowe**  
   - Aktualizacje indeksów, utrzymanie columnstore, statystyki (ew. auto update), trigger’y.

---

## 6. Wyniki i ich przesłanie do klienta

1. **Format wyników**  
   - Wyniki formatuje Execution Engine i przesyła strumieniowo do klienta w pakietach TDS.

2. **Network / driver**  
   - Driver odbiera pakiety, mapuje je na DataReader/DataSet/ResultSet.  
   - Przy dużych wynikach transfer odbywa się partiami (fetch/paging).

3. **Connection pooling**  
   - Po `Close()` połączenie zwracane do puli; stan sesji jest resetowany (`sp_reset_connection`) — to jest szybkie, ale trzeba pamiętać o nieprzechowywaniu tymczasowych ustawień w pulowanych połączeniach.

---

## 7. Optymalizacje i mechanizmy wpływające na zachowanie

- **Plan caching** → oszczędza CPU, ale czasem wymaga własnej strategii (plan forcing, plan guide).  
- **Parameterization / Prepared statements** → lepsze reuse planów, mniejszy parsing overhead.  
- **Statistics** → aktualne statystyki = lepsze plany; `AUTO_UPDATE_STATISTICS` pomaga, ale może być opóźnione.  
- **Parallel execution** → duże zapytania mogą rozłożyć pracę na wiele workerów (MAXDOP).  
- **Batching / TVPs** → zmniejszają round-tripy i poprawiają throughput.  
- **MARS (Multiple Active Result Sets)** → pozwala na jednoczesne otwarte resultsety na tym samym połączeniu (ma ograniczenia i overhead).

---

## 8. Błędy i diagnostyka — co sprawdzić, gdy coś nie działa

- **Połączenie**: czy port/instancja/SQL Browser działają? (TCP 1433, UDP 1434)  
- **Uwierzytelnienie**: błędy loginu (error 18456) → uprawnienia/Kerberos.  
- **Timeouts**: network timeout vs command timeout (różne parametry).  
- **Brak planu / złe plany**: `sys.dm_exec_cached_plans`, `sys.dm_exec_query_stats`, Query Store.  
- **Blocking / deadlock**: `sys.dm_tran_locks`, `sys.dm_exec_requests`, Extended Events / XE session.  
- **I/O / wait stats**: `sys.dm_io_virtual_file_stats`, `sys.dm_os_wait_stats`.  
- **Corrupted pages / log**: `DBCC CHECKDB`, errorlog, RESTORE VERIFYONLY.

---

## 9. Przykładowe connection stringi (szybko)
- ADO.NET Windows auth:
  ```
  Server=myServerName\myInstanceName;Database=MyDB;Integrated Security=True;Encrypt=True;TrustServerCertificate=False;
  ```
- ADO.NET SQL auth:
  ```
  Server=myServer;Database=MyDB;User Id=myUser;Password=myPass;Encrypt=True;
  ```
- ODBC:
  ```
  Driver={ODBC Driver 17 for SQL Server};Server=tcp:myserver,1433;Database=MyDB;UID=user;PWD=pass;Encrypt=yes;
  ```

---

## 10. Krótkie checklisty — co optymalizować w app ↔ serwer integracji

- **W aplikacji**
  - Używaj parametrów / przygotowanych zapytań.  
  - Zadbaj o pooling i poprawne `Close()`/`Dispose()`.  
  - Ustaw sensowne timeouts.

- **Na serwerze**
  - Monitoruj plan cache i Query Store.  
  - Trzymaj statystyki aktualne.  
  - Dostosuj MAXDOP i Memory (Buffer Pool).  
  - Dbaj o indeksy i reguły automaintenance.

---

_ostatnia aktualizacja: 2025-09-16_
