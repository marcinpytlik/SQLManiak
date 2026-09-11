# SQL Server CDC — wymagania, ograniczenia i uwagi projektowe

Ten dokument opisuje najważniejsze wymagania i ograniczenia **Change Data Capture (CDC)** w SQL Server przed uruchomieniem POC lub wdrożeniem rozwiązania produkcyjnego.

> **Ważne:** SQL Server CDC nie wymaga bezwzględnie `PRIMARY KEY`, aby śledzić tabelę. Klucz główny lub inny unikalny indeks jest jednak wymagany, jeśli chcemy używać `net changes`, a także jest bardzo istotny dla narzędzi takich jak Debezium, które potrzebują stabilnego klucza rekordu.

---

## 1. Co robi CDC

CDC odczytuje zmiany z transaction loga i zapisuje je w specjalnych tabelach w schemacie `cdc`.

Przechwytywane są operacje:

- `INSERT`
- `UPDATE`
- `DELETE`

Dla każdej instancji capture tworzona jest tabela zmian, np.:

```sql
cdc.dbo_Customer_CT
```

W tabeli zmian znajdują się dodatkowo kolumny techniczne, m.in.:

- `__$start_lsn`
- `__$end_lsn`
- `__$seqval`
- `__$operation`
- `__$update_mask`

Znaczenie `__$operation`:

| Wartość | Operacja |
|---:|---|
| 1 | DELETE |
| 2 | INSERT |
| 3 | UPDATE — before image |
| 4 | UPDATE — after image |

---

## 2. Czy PRIMARY KEY jest wymagany?

### Do zwykłego CDC — nie

Tabelę można włączyć do CDC nawet wtedy, gdy nie ma `PRIMARY KEY`.

W takim przypadku:

```sql
@supports_net_changes = 0
```

CDC nadal będzie przechwytywać wszystkie zmiany.

### Do `net changes` — tak, albo wymagany jest UNIQUE INDEX

Jeżeli chcemy korzystać z:

```sql
cdc.fn_cdc_get_net_changes_<capture_instance>
```

tabela musi mieć:

- `PRIMARY KEY`, albo
- odpowiedni `UNIQUE INDEX` wskazany parametrem `@index_name`.

Przykład:

```sql
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @role_name = NULL,
    @supports_net_changes = 1;
```

Jeżeli tabela posiada `PRIMARY KEY`, CDC automatycznie użyje indeksu powiązanego z tym kluczem.

### Ważna konsekwencja

Jeżeli tabela posiada `PRIMARY KEY` w momencie włączania CDC, CDC zapamiętuje ten indeks.

Po włączeniu CDC nie można swobodnie zmienić tego klucza bez wcześniejszego wyłączenia CDC dla tabeli.

Jeżeli tabela nie miała `PRIMARY KEY` podczas włączania CDC, a dodamy go później, istniejąca capture instance nie zacznie automatycznie z niego korzystać.

---

## 3. Wymagania dotyczące SQL Server Agent

W klasycznym SQL Server CDC wykorzystuje joby SQL Server Agent:

- `cdc.<DatabaseName>_capture`
- `cdc.<DatabaseName>_cleanup`

Capture job odczytuje transaction log i przenosi zmiany do tabel CDC.

Cleanup job usuwa stare dane zgodnie z ustawioną retencją.

Dlatego należy monitorować:

```sql
EXEC sys.sp_cdc_help_jobs;
```

oraz:

```sql
SELECT *
FROM msdb.dbo.cdc_jobs;
```

Jeżeli capture job nie działa, zmiany pozostają w transaction logu i CDC zaczyna generować backlog.

---

## 4. Typy danych

Microsoft deklaruje obsługę wszystkich podstawowych typów kolumn, ale część z nich ma specjalne zachowanie.

### `computed column`

Zmiany wartości computed column nie są przechwytywane.

Kolumna może istnieć w tabeli zmian, ale jej wartość będzie:

```text
NULL
```

Nie należy więc traktować computed column jako źródła danych dla konsumenta CDC.

---

### `timestamp` / `rowversion`

Kolumny `timestamp` / `rowversion` są przechwytywane, ale w tabeli CDC są reprezentowane jako:

```sql
binary(8)
```

---

### `text`, `ntext`, `image`

Typy te są obsługiwane, ale mają specjalne zachowanie.

Dla `DELETE` oraz obrazu `UPDATE BEFORE` wartości mogą być zapisane jako `NULL`.

Typy te są również przestarzałe w SQL Server i nie powinny być używane w nowych rozwiązaniach.

Preferowane odpowiedniki:

```text
text   -> varchar(max)
ntext  -> nvarchar(max)
image  -> varbinary(max)
```

---

### `varchar(max)`, `nvarchar(max)`, `varbinary(max)`

Dla dużych obiektów obowiązują szczególne zasady przechowywania obrazu przed zmianą.

Przy `UPDATE` wartość `before image` może być `NULL`, jeśli dana kolumna nie została zmodyfikowana.

Jeżeli sama kolumna LOB została zmieniona, CDC przechowuje jej odpowiednią wartość.

---

### `XML`

Kolumny XML są obsługiwane.

CDC nie śledzi jednak zmian na poziomie pojedynczego elementu XML.

Dla CDC zmiana XML jest zmianą całej wartości kolumny.

---

### `SPARSE`

Sparse columns mogą być przechwytywane.

Ograniczeniem jest używanie `COLUMN_SET` — CDC nie obsługuje poprawnie śledzenia zmian przez column set.

---

## 5. Collation

Szczególną uwagę należy zwrócić na kolumny `char` i `varchar`, jeżeli posiadają inną collation niż baza danych.

Przy danych non-ASCII istnieje ryzyko niepoprawnego zapisania danych w strukturach pośrednich CDC.

Bezpieczniejsze rozwiązania:

- użycie tej samej collation dla kolumny i bazy,
- zastosowanie `nchar` / `nvarchar` dla danych Unicode.

---

## 6. Zmiany struktury tabeli

CDC nie działa jak dynamiczna replika schematu.

Capture instance posiada określony zestaw przechwytywanych kolumn.

### Dodanie nowej kolumny

Jeżeli wykonamy:

```sql
ALTER TABLE dbo.Customer
ADD Phone varchar(50) NULL;
```

istniejąca capture instance nie zacznie automatycznie zwracać tej kolumny w funkcjach CDC.

Nowa kolumna nie jest automatycznie dodawana do istniejącego zestawu captured columns.

### Usunięcie kolumny

Usunięcie kolumny ze źródła również nie oznacza automatycznej przebudowy capture instance.

### Zmiana typu danych

Zmiana typu kolumny może wymusić aktualizację struktury change table i w określonych sytuacjach doprowadzić do problemów capture process.

Historię DDL możemy sprawdzić:

```sql
EXEC sys.sp_cdc_get_ddl_history
    @capture_instance = N'dbo_Customer';
```

### Zalecenie

Przy większych zmianach schematu bezpieczniejszym podejściem jest:

1. zaplanowanie migracji konsumentów,
2. utworzenie nowej capture instance lub ponowne włączenie CDC,
3. zweryfikowanie zakresu przechwytywanych kolumn.

---

## 7. Maksymalnie dwie capture instances dla jednej tabeli

SQL Server pozwala posiadać maksymalnie dwie capture instances dla jednej tabeli źródłowej.

Mechanizm ten jest przydatny właśnie podczas zmian schematu.

Możemy tymczasowo posiadać:

```text
dbo_Customer

dbo_Customer_v2
```

co pozwala na kontrolowane przejście konsumenta na nowy schemat.

---

## 8. PARTITION SWITCH

`ALTER TABLE ... SWITCH PARTITION` wymaga szczególnej uwagi.

Switch partition jest operacją metadanych i dane przesunięte w ramach tej operacji nie są widziane przez CDC jako klasyczne `INSERT` / `DELETE`.

Może to spowodować niespójność danych u konsumenta CDC.

Jeżeli system intensywnie wykorzystuje partition switching, trzeba to osobno uwzględnić w architekturze CDC.

---

## 9. TRUNCATE TABLE

CDC bazuje na zmianach rejestrowanych na poziomie rekordów w transaction logu.

`TRUNCATE TABLE` nie generuje indywidualnych operacji `DELETE` dla każdego rekordu.

Dlatego nie należy traktować `TRUNCATE` jako operacji, którą konsument CDC zobaczy jako serię usunięć wierszy.

Jeżeli konsument ma posiadać identyczny stan danych, masowe czyszczenie tabel należy projektować świadomie.

---

## 10. Transaction Log

CDC czyta transaction log.

Jeżeli capture process nie nadąża, log nie może zostać oczyszczony z części danych potrzebnych CDC.

Może to doprowadzić do:

- wzrostu transaction log,
- problemów z reuse logu,
- wzrostu CDC latency,
- dużego backlogu.

Dlatego CDC należy traktować również jako element wpływający na strategię utrzymania logu.

Warto monitorować:

```sql
SELECT *
FROM sys.dm_cdc_log_scan_sessions
ORDER BY session_id DESC;
```

oraz:

```sql
SELECT *
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
```

---

## 11. Retencja

CDC nie przechowuje zmian bezterminowo.

Cleanup job usuwa dane według ustawienia `retention`.

Przykład:

```sql
EXEC sys.sp_cdc_change_job
    @job_type = N'cleanup',
    @retention = 4320;
```

`4320` oznacza trzy doby.

### Najważniejsza konsekwencja

Jeżeli konsument zatrzyma się na dłużej niż retencja CDC, może utracić możliwość odczytania brakujących zmian.

Przy integracji z Debezium jest to jeden z najważniejszych scenariuszy awaryjnych do przetestowania.

---

## 12. Backup / Restore

Przy restore należy pamiętać o zachowaniu konfiguracji CDC.

Przywracanie bazy na inny serwer może spowodować wyłączenie CDC.

Jeżeli chcemy zachować metadane CDC, dostępna jest opcja:

```sql
RESTORE DATABASE ... WITH KEEP_CDC;
```

Po restore należy zawsze sprawdzić:

```sql
SELECT name, is_cdc_enabled
FROM sys.databases
WHERE name = DB_NAME();
```

oraz stan jobów capture i cleanup.

---

## 13. ADR — Accelerated Database Recovery

W SQL Server 2019 współpraca CDC z ADR ma ograniczenia.

Wspólne użycie CDC i ADR jest obsługiwane w nowszych wersjach SQL Server, m.in. od SQL Server 2022 CU18.

CDC może wpływać na możliwość agresywnego truncation transaction logu, ponieważ skaner CDC potrzebuje dostępu do odpowiednich fragmentów logu.

W systemach z dużym wolumenem zmian należy monitorować wykorzystanie logu szczególnie dokładnie.

---

## 14. Uprawnienia

Do włączania CDC na poziomie bazy wymagane są odpowiednie uprawnienia administracyjne.

Typowo operacje administracyjne CDC wykonuje `db_owner` / `sysadmin`.

Dostęp do danych CDC można ograniczyć rolą podawaną w parametrze:

```sql
@role_name
```

Przykład:

```sql
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @role_name = N'cdc_reader',
    @supports_net_changes = 1;
```

Konsument CDC nie musi być `db_owner`.

---

## 15. Nie modyfikujemy ręcznie obiektów CDC

Nie należy ręcznie modyfikować:

- schematu `cdc`,
- tabel `_CT`,
- systemowych procedur CDC,
- metadanych CDC,
- użytkownika `cdc`.

Obiekty oznaczone jako `is_ms_shipped = 1` powinny być traktowane jako systemowe.

---

## 16. CDC a Debezium

W naszym POC drugi etap będzie wyglądał następująco:

```text
Application
    |
    v
SQL Server
    |
    v
Transaction Log
    |
    v
SQL Server CDC
    |
    v
CDC Change Tables
    |
    v
Debezium
    |
    v
Kafka
    |
    v
Consumer
```

Dla Debezium szczególnie istotne są:

- stabilny `PRIMARY KEY`,
- jednoznaczna identyfikacja rekordu,
- odpowiednio długa retencja CDC,
- brak niekontrolowanych zmian schematu,
- monitoring capture job,
- monitoring backlogu,
- kontrola wzrostu transaction logu,
- test restartu connectora,
- test długiej niedostępności connectora,
- test DDL,
- test `DELETE`,
- test zmian PK,
- test utraty zakresu LSN przez cleanup.

W praktyce dla Debezium powinniśmy traktować `PRIMARY KEY` jako **wymaganie architektoniczne**, nawet jeśli sam SQL Server CDC potrafi pracować bez niego.

---

## 17. Checklista przed włączeniem CDC

Przed włączeniem tabeli do CDC warto sprawdzić:

- [ ] Czy tabela posiada `PRIMARY KEY`?
- [ ] Czy klucz jednoznacznie identyfikuje rekord?
- [ ] Czy potrzebujemy `net changes`?
- [ ] Czy tabela zawiera computed columns?
- [ ] Czy tabela zawiera LOB-y?
- [ ] Czy są używane `text`, `ntext`, `image`?
- [ ] Czy tabela ma niestandardowe collations?
- [ ] Czy używany jest partition switching?
- [ ] Czy aplikacja wykonuje masowe operacje typu truncate / partition switch?
- [ ] Czy planowane są częste zmiany schematu?
- [ ] Jaka powinna być retencja CDC?
- [ ] Ile zmian generuje tabela na godzinę / dobę?
- [ ] Czy transaction log ma odpowiedni rozmiar?
- [ ] Czy autogrowth logu jest sensownie ustawiony?
- [ ] Czy SQL Server Agent działa?
- [ ] Czy capture job jest monitorowany?
- [ ] Czy cleanup job jest monitorowany?
- [ ] Czy konsument potrafi wznowić odczyt po restarcie?
- [ ] Co stanie się, gdy konsument będzie offline dłużej niż retention?

---

## 18. Polecane zapytania kontrolne

### Czy CDC jest włączone na bazie

```sql
SELECT
    name,
    is_cdc_enabled
FROM sys.databases
WHERE name = DB_NAME();
```

### Tabele objęte CDC

```sql
SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    t.is_tracked_by_cdc
FROM sys.tables AS t
JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE t.is_tracked_by_cdc = 1;
```

### Capture instances

```sql
EXEC sys.sp_cdc_help_change_data_capture;
```

### Captured columns

```sql
EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer';
```

### Joby CDC

```sql
EXEC sys.sp_cdc_help_jobs;
```

### Ostatnie sesje skanowania logu

```sql
SELECT TOP (20) *
FROM sys.dm_cdc_log_scan_sessions
ORDER BY session_id DESC;
```

### Błędy CDC

```sql
SELECT *
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
```

---

## 19. Dokumentacja Microsoft

- Track data changes — SQL Server  
  https://learn.microsoft.com/sql/relational-databases/track-changes/track-data-changes-sql-server

- Enable and disable Change Data Capture  
  https://learn.microsoft.com/sql/relational-databases/track-changes/enable-and-disable-change-data-capture-sql-server

- Administer and monitor Change Data Capture  
  https://learn.microsoft.com/sql/relational-databases/track-changes/administer-and-monitor-change-data-capture-sql-server

- Known issues and limitations  
  https://learn.microsoft.com/sql/relational-databases/track-changes/known-issues-and-errors-change-data-capture

- CDC and other SQL Server features  
  https://learn.microsoft.com/sql/relational-databases/track-changes/change-data-capture-and-other-sql-server-features

- `cdc.<capture_instance>_CT`  
  https://learn.microsoft.com/sql/relational-databases/system-tables/cdc-capture-instance-ct-transact-sql

- `cdc.change_tables`  
  https://learn.microsoft.com/sql/relational-databases/system-tables/cdc-change-tables-transact-sql

---

## 20. Wnioski dla naszego POC

W SQLLab przyjmujemy następujące zasady:

1. Tabele testowe posiadają `PRIMARY KEY`.
2. CDC konfigurujemy z `@supports_net_changes = 1`.
3. Testujemy zarówno `all changes`, jak i `net changes`.
4. Testujemy `INSERT`, `UPDATE` i `DELETE`.
5. Sprawdzamy fizyczne tabele `_CT`.
6. Monitorujemy capture job, cleanup job i log scan sessions.
7. Sprawdzamy wpływ retencji.
8. Testujemy zmianę schematu.
9. Testujemy zatrzymanie capture job i wzrost backlogu.
10. W kolejnym etapie podłączamy Debezium i Kafka.

Celem POC nie jest tylko wykazanie, że CDC działa, ale również sprawdzenie jego zachowania w scenariuszach awaryjnych i operacyjnych typowych dla środowiska produkcyjnego.
