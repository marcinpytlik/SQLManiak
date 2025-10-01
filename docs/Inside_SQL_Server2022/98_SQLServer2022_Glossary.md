# 🔥 SQL Server Glossary – Level 4 (Internals Hardcore)

## Core Internals

| Pojęcie | Opis techniczny | Poziom |
|---------|-----------------|--------|
| **PFS (Page Free Space)** | Strona specjalna co 8088 stron w pliku, trzyma info o wolnym miejscu na stronach danych. Krytyczna przy alokacji nowych wierszy. | 4 |
| **GAM/SGAM** | Global Allocation Map i Shared Global Allocation Map – bitmapy opisujące, które extent’y (64 KB) są wolne lub częściowo zajęte. | 4 |
| **IAM (Index Allocation Map)** | Strona mapująca, które extent’y należą do konkretnego obiektu (tabela, indeks). | 4 |
| **HOBT (Heap Or B-Tree)** | Jednostka organizacyjna – reprezentuje tabelę jako heap albo B-tree indeks. Każdy indeks w SQL = osobny HOBT. | 4 |
| **VLF (Virtual Log File)** | Podział pliku dziennika transakcji (LDF) na segmenty. Zbyt wiele małych VLF = wolne recovery. | 4 |
| **Write-Ahead Logging (WAL)** | Zasada: zanim dane trafią na stronę MDF, wpis musi być w logu LDF. Fundament ARIES. | 4 |
| **ARIES (Analysis, Redo, Undo)** | Algorytm recovery: analiza transakcji, odtwarzanie zatwierdzonych (redo), wycofywanie niezatwierdzonych (undo). | 4 |
| **Ghost Records** | Wiersze oznaczone jako usunięte, czyszczone asynchronicznie przez Ghost Cleanup Task. Widać w DMVs i w sys.dm_db_index_physical_stats. | 4 |
| **PAGELATCH / PAGEIOLATCH** | Latches – lekkie blokady na stronach w pamięci (PAGELATCH) lub przy I/O (PAGEIOLATCH). Diagnoza bottlenecków dyskowych. | 4 |
| **SOS Scheduler** | Scheduler (harmonogram) SQL Server zarządzający wątkami. Jeden scheduler ≈ jeden rdzeń CPU. Kluczowy DMV: sys.dm_os_schedulers. | 4 |
| **CXPACKET / CXCONSUMER** | Wait statsy związane z równoległością zapytań (parallelism). CXCONSUMER = „normalny” wait, CXPACKET często = symptom złego planu. | 4 |
| **Spinlock** | Ultra-lekka synchronizacja między wątkami (niższy poziom niż latch). Przeciążone spinlocki = wysokie CPU. | 4 |
| **Latch Promotion** | Mechanizm eskalacji lekkich blokad latch do cięższych (np. gdy konfliktów jest zbyt wiele). | 4 |
| **Log Sequence Number (LSN)** | Unikalny numer wpisu w logu transakcyjnym. Wszystko w backup/restore opiera się na LSN. | 4 |
| **MinLSN** | Najmniejszy LSN potrzebny do recovery – determinuje, które części loga można „ztruncate’ować”. | 4 |
| **Dirty Page** | Strona w buffer pool zmieniona, ale jeszcze nie zapisana na dysk. Flushowane przez checkpoint/lazy writer. | 4 |
| **Write-Ahead Buffer** | Obszar w pamięci, gdzie wpisy loga czekają na zapis do pliku LDF (przed flush). | 4 |
| **Accelerated Database Recovery (ADR)** | Mechanizm od SQL 2019 – szybkie undo dzięki „persisted version store”. Minimalizuje czas recovery. | 4 |
| **Persisted Version Store (PVS)** | Struktura w bazie trzymająca starsze wersje wierszy (dla ADR i snapshot isolation). | 4 |
| **Indirect Checkpoint** | Ulepszony checkpoint (od SQL 2012), kontrolowany parametrem Target Recovery Time. | 4 |
| **Checkpoint LSN** | LSN, do którego zapisane są wszystkie zmiany na dysku. Punkt odniesienia dla recovery. | 4 |
| **XEvent (Extended Events)** | Lekkie narzędzie diagnostyczne, zastępuje Profiler/Trace. Można podejrzeć latches, spinlocki, log flush. | 4 |
| **sys.fn_PhysLocCracker** | Funkcja pozwalająca rozbić fizyczną lokalizację wiersza na File:Page:Slot. Niezastąpiona przy analizie internals. | 4 |
| **DBCC PAGE / DBCC IND** | Ukryte komendy do podglądu stron i struktur wewnętrznych MDF. Must-have przy analizie ghostów i HOBT. | 4 |

---

## Extended (TDS, PHD, ODS etc.)

| Pojęcie | Opis techniczny | Poziom |
|---------|-----------------|--------|
| **TDS (Tabular Data Stream)** | Protokół sieciowy Microsoftu, którym SQL Server gada z klientem (SSMS, ADO.NET, ODBC). Każda sesja SPID to strumień TDS. Pakiety zawierają login, zapytania, metadane, wyniki. | 4 |
| **PHD (Page Header Data)** | Nagłówek strony danych (96 bajtów), zawiera m.in. Page ID, Object ID, Checksum, modyfikacje LSN, wskaźniki slot array. Każda strona 8 KB zaczyna się od PHD. | 4 |
| **ODS (On-Disk Structure)** | Formalny opis struktur fizycznych na dysku – np. stron danych, extentów, IAM, GAM, PFS. Każda wersja SQL ma numer ODS (np. ODS 782 w SQL 2019). Zmiana ODS = brak kompatybilności „w dół”. | 4 |
| **Metadata Pages** | Specjalne strony przechowujące metadane obiektów (np. sysobjects, sysschobjs). Są częścią ODS i widoczne przez DBCC PAGE. | 4 |
| **Boot Page** | Strona 9 w pliku bazy MDF, przechowuje krytyczne info o bazie: name, DBID, ustawienia, compatibility level. Bez niej baza = cegła. | 4 |
| **Differential Changed Map (DCM)** | Strony bitmapowe, oznaczające które extenty zmieniły się od ostatniego pełnego backupu. Kluczowe dla backupu diff. | 4 |
| **Bulk Changed Map (BCM)** | Strony bitmapowe dla extentów zapisanych w trybie BULK_LOGGED. Wykorzystywane przy backupach logów. | 4 |
| **FID:PID:Slot** | Fizyczna lokalizacja wiersza: File ID, Page ID, Slot ID. Rozbijane np. przez sys.fn_PhysLocCracker. | 4 |
| **Slot Array** | Fragment nagłówka strony zawierający wskaźniki na każdy wiersz w obrębie strony. Umożliwia reorganizację rekordów bez przenoszenia danych. | 4 |
| **Row Offset Array** | Synonim Slot Array – tabela wskaźników na początek rekordów na stronie. | 4 |
| **sys.sysrscols** | Ukryta tabela katalogowa z definicjami kolumn. Źródło prawdy o strukturze tabel. | 4 |
| **IAM Chain** | Łańcuch stron IAM mapujących wszystkie extenty należące do danego HOBT. | 4 |
| **PFS byte states** | Bajt w PFS koduje stopień zajęcia strony (0%, 1-50%, 51-80%, 81-95%, 96-100%). Dzięki temu SQL szybko wybiera stronę z wolnym miejscem. | 4 |
| **ODS Versioning** | Numer struktury on-disk (ODS) jest zapisany w nagłówku pliku MDF. SQL Server nie otworzy pliku z wyższym ODS niż obsługiwany. | 4 |


---

## Extra Nuggets (Hardcore Internals Add-ons)

| Pojęcie | Opis techniczny | Poziom |
|---------|-----------------|--------|
| **DBCC CHECKDB / CHECKFILEGROUP** | Diagnostyka spójności stron i obiektów. CHECKDB korzysta ze snapshotu bazy i skanuje wszystkie struktury. | 4 |
| **Extent** | Jednostka alokacji danych, 64 KB (8 stron po 8 KB). Może być uniform (dla jednego obiektu) lub mixed (dla wielu obiektów). | 4 |
| **IAM Chain Depth** | Głębokość łańcucha stron IAM w bardzo dużych tabelach. Wpływa na wydajność odczytów sekwencyjnych. | 4 |
| **File Header Page** | Strona 0 w pliku danych MDF/NDF, zawiera informacje o pliku (FileID, rozmiar, ODS, ścieżkę). | 4 |
| **Proportional Fill** | Algorytm równoważący zapisy między plikami w tej samej grupie plików. Nierówne pliki = nierówna alokacja. | 4 |
| **Log Flush Wait** | Czekanie aż wpisy loga w buforze zostaną spłukane do pliku LDF. Często przyczyną wysokiego WRITELOG wait. | 4 |
| **Allocation Units** | Trzy typy: IN_ROW_DATA, LOB_DATA, ROW_OVERFLOW_DATA – dla różnych typów kolumn i przechowywania. | 4 |
| **Sysobj Tables (sysschobjs, sysrowsets)** | Ukryte systemowe tabele katalogowe przechowujące metadane obiektów i kolumn. | 4 |
| **Minimal Logging** | Tryb BULK_LOGGED lub SIMPLE dla niektórych operacji (bulk insert, select into). Przyspiesza, ale komplikuje restore. | 4 |
| **Checkpoint Queue** | Kolejka stron dirty obsługiwana przez workerów checkpointu. Może być wąskim gardłem przy intensywnym zapisie. | 4 |
| **Recovery Interval** | Parametr instancji określający docelowy czas recovery. Historycznie używany przed wprowadzeniem indirect checkpoint. | 4 |
| **Log Block** | Jednostka zapisu w logu transakcyjnym (60 KB). Minimalna paczka flush do pliku LDF. | 4 |
| **Latch Classes** | Kategorie latchy (np. BUF, PAGELATCH_EX, IO_COMPLETION). Analiza przez XEvents daje obraz konfliktów pamięciowych. | 4 |
| **System Base Tables** | Ukryte obiekty w pliku mssqlsystemresource.mdf – fundament katalogu systemowego. | 4 |


---

## Engine Deep Dive (Level 4++)

| Pojęcie | Opis techniczny | Poziom |
|---------|-----------------|--------|
| **CMEMTHREAD** | Typ memory clerka, często źródło contention (wąskie gardła) przy współbieżnych workloadach. Powiązane ze spinlockami. | 4 |
| **SOS_RWLock** | Reader-Writer Lock używany wewnętrznie w SQL do synchronizacji dostępu do metadanych. | 4 |
| **Free Space Scan** | Mechanizm wyszukiwania stron z wolnym miejscem w PFS przy insertach. Może spowalniać intensywne inserty w tempdb. | 4 |
| **SOS_SCHEDULER_YIELD** | Wait stat oznaczający oddanie kwantu czasu przez wątek SQL. Typowy dla CPU-bound queries. | 4 |
| **Parallel Exchange Operators** | Operatory planu zapytania (Distribute, Repartition, Gather Streams). Wydajność śledzona przez EXCHANGE waits. | 4 |
| **Lazy Writer Stall** | Sytuacja, gdy lazy writer nie nadąża z czyszczeniem stron w buffer pool → presja pamięci. | 4 |
| **Lock Escalation** | Eskalacja blokad z row/page do poziomu table-level przy zbyt dużej liczbie locków. | 4 |
| **Spinlock Hashing** | Spinlocki przypisane do bucketów hash w celu zmniejszenia contention. Analiza: sys.dm_os_spinlock_stats. | 4 |
| **Thread Pool Wait** | Brak dostępnych workerów w puli wątków. Objawia się brakiem nowych sesji (SPID nie dostaje workera). | 4 |
| **UCS2 / Collation Internals** | Mechanizm przechowywania i sortowania znaków (CI/CS/AI/AS). Wpływa na wydajność i logikę porównań. | 4 |
| **Internal Table Types** | Worktables (sort/hash), version store, spool tables – tworzone dynamicznie, głównie w tempdb. | 4 |
| **Latch Partitioning** | Rozdzielanie allocation mapów między wiele plików w tempdb, aby zmniejszyć contention. | 4 |
| **Memory Grant Feedback** | Mechanizm (od SQL 2017+) automatycznie dostosowujący pamięć dla operatorów zapytań. | 4 |
| **Batch Mode on Rowstore** | Od SQL 2019+, możliwość uruchamiania silnika kolumnowego na indeksach rowstore. | 4 |
| **Query Compilation Replay (QCR)** | Mechanizm „odtwarzania” kompilacji zapytania w Query Store, stabilizujący plany. | 4 |


---

## SQLOS & Hidden Internals (Level 4+++)

| Pojęcie | Opis techniczny | Poziom |
|---------|-----------------|--------|
| **SQLOS** | Warstwa abstrakcji SQL Server działająca jak mini system operacyjny. Zarządza schedulerami, workerami, pamięcią, spinlockami i I/O. | 4 |
| **Worker / Task / Fiber** | Task = jednostka pracy, Worker = wątek wykonawczy, Fiber = lekki worker (lightweight pooling, dziś praktycznie niewykorzystywany). | 4 |
| **CLR Host** | Wbudowany host środowiska .NET w SQL Server, umożliwia pisanie procedur i funkcji w językach CLR (np. C#). | 4 |
| **SOS Scheduler Affinity** | Możliwość przypięcia schedulerów SQL do CPU/NUMA nodes. Błędna konfiguracja = hot spoty CPU. | 4 |
| **NUMA Awareness** | SQL Server świadomy architektury NUMA, dzieli schedulery, clerks i buffer pool per NUMA node. | 4 |
| **IOCP (I/O Completion Ports)** | Mechanizm Windows API do obsługi asynchronicznych I/O i sieci. SQL Server integruje to w SQLOS. | 4 |
| **VAS Reservation** | Rezerwacja dużych bloków adresów pamięci (Virtual Address Space) dla buffer pool i clerks. Historyczny problem na 32-bit. | 4 |
| **Resource DB (mssqlsystemresource)** | Ukryta, tylko-do-odczytu baza zawierająca wszystkie obiekty systemowe. Traktowana jak DLL SQL Server. | 4 |
| **DAC (Dedicated Admin Connection)** | Specjalny kanał (-A) pozwalający zalogować się do SQL, nawet gdy engine nie przyjmuje zwykłych sesji. | 4 |
| **Hidden DMVs** | DMVs „dla inżynierów SQL”, np. sys.dm_os_spinlock_stats, sys.dm_os_memory_objects. Niedokumentowane, ale użyteczne. | 4 |
| **Lightweight Pooling (Fibers)** | Trace flag umożliwiający fiber pooling. Deprecated, ale historycznie ciekawy eksperyment. | 4 |
| **Optimizer Phases** | Fazy kompilacji zapytań: parser → algebrizer → optimizer → executor. Każda ma własne ukryte XEvents. | 4 |
| **Statistics Objects** | Obiekty w sys.sysobjvalues zawierające histogramy i density vectors, decydujące o planach zapytań. | 4 |
| **Cardinality Estimator (CE)** | Osobny komponent estymujący liczność wyników. CE stary (pre-2014) i nowy (2014+). | 4 |
| **Trace Flags** | Ukryte przełączniki kontrolujące zachowanie engine (np. TF 1117, 1118, 4199). | 4 |
| **Heaps vs B-Trees** | Różnice w wewnętrznych strukturach – heaps nie mają order key, co powoduje RID lookups i ghosty. | 4 |
| **Parallel Scan Granularity** | Przy dużych tabelach SQL dzieli dane na rowsets po IAM chainach, by równolegle je skanować. | 4 |
| **QDS (Query Data Store)** | Wewnętrzne repozytorium Query Store, oparte o ukryte procedury i systemowe tabele. | 4 |
