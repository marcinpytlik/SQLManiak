# SQL Server CDC — Operational Runbook

Ten dokument opisuje bezpieczne operacje administracyjne dla tabel objętych Change Data Capture (CDC): zmiany schematu, wymianę capture instance, ponowną inicjalizację konsumenta, reset środowiska, kontrolę LSN oraz procedury diagnostyczne.

> Najważniejsza zasada: istniejąca capture instance ma stały zestaw przechwytywanych kolumn przez cały swój cykl życia. Dodanie lub usunięcie kolumny w tabeli źródłowej nie zmienia automatycznie definicji istniejącej capture instance.

---

## 1. Szybka checklista przed każdą zmianą

Przed zmianą tabeli objętej CDC:

```sql
USE CDC_Lab;
GO

EXEC sys.sp_cdc_help_change_data_capture;
GO

EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer';
GO

EXEC sys.sp_cdc_get_ddl_history
    @capture_instance = N'dbo_Customer';
GO
```

Sprawdź również:

```sql
SELECT
    capture_instance,
    start_lsn,
    supports_net_changes,
    index_name,
    filegroup_name
FROM cdc.change_tables;
GO
```

Jeżeli downstream zapisuje własny watermark/LSN, zanotuj go przed zmianą.

---

# 2. Dodanie kolumny do tabeli objętej CDC

Załóżmy, że mamy tabelę:

```sql
dbo.Customer
```

i capture instance:

```text
dbo_Customer
```

Chcemy dodać kolumnę:

```sql
ALTER TABLE dbo.Customer
ADD PhoneNumber varchar(30) NULL;
GO
```

## Co stanie się z istniejącą capture instance?

Tabela źródłowa będzie miała nową kolumnę, ale istniejąca capture instance `dbo_Customer` nadal będzie miała poprzedni zestaw kolumn.

Nowa kolumna nie pojawi się automatycznie w:

```text
cdc.dbo_Customer_CT
```

ani w funkcjach:

```text
cdc.fn_cdc_get_all_changes_dbo_Customer
cdc.fn_cdc_get_net_changes_dbo_Customer
```

Sprawdzenie:

```sql
EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer';
GO
```

---

## 2.1. Zalecany sposób — druga capture instance

SQL Server pozwala na maksymalnie dwie capture instances dla jednej tabeli. To umożliwia bezpieczną migrację schematu bez natychmiastowego odcięcia starego konsumenta.

Tworzymy nową capture instance:

```sql
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer_v2',
    @role_name = NULL,
    @supports_net_changes = 1;
GO
```

Sprawdzamy:

```sql
EXEC sys.sp_cdc_help_change_data_capture
    @source_schema = N'dbo',
    @source_name = N'Customer';
GO
```

oraz:

```sql
EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer_v2';
GO
```

Nowa capture instance powinna już zawierać `PhoneNumber`.

### Model migracji

```text
Tabela źródłowa
      |
      +---- dbo_Customer      -> stary konsument
      |
      +---- dbo_Customer_v2   -> nowy konsument
```

Przez okres przejściowy obie capture instances mogą działać równolegle.

Po przełączeniu konsumenta na `dbo_Customer_v2` starą capture instance można usunąć:

```sql
EXEC sys.sp_cdc_disable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer';
GO
```

---

# 3. Usunięcie kolumny z tabeli objętej CDC

Załóżmy, że chcemy usunąć:

```text
PhoneNumber
```

Najpierw sprawdź, czy kolumna jest przechwytywana:

```sql
EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer';
GO
```

Następnie:

```sql
ALTER TABLE dbo.Customer
DROP COLUMN PhoneNumber;
GO
```

## Co dzieje się z istniejącą capture instance?

Definicja istniejącej capture instance pozostaje niezmieniona.

Jeżeli usunięta kolumna była przechwytywana, historyczna change table nadal posiada tę kolumnę. Dla nowych zmian SQL Server może zapisywać w niej `NULL`.

Dlatego przy trwałej zmianie kontraktu danych zalecana jest wymiana capture instance.

---

## 3.1. Bezpieczna procedura usunięcia kolumny

Najbezpieczniejszy wariant:

1. utworzyć nową capture instance bez kolumny,
2. przełączyć konsumenta,
3. potwierdzić poprawny odczyt,
4. usunąć starą capture instance,
5. dopiero wtedy usunąć kolumnę z tabeli źródłowej, jeśli kolejność operacji aplikacyjnych na to pozwala.

Przykład:

```sql
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer_v2',
    @role_name = NULL,
    @supports_net_changes = 1,
    @captured_column_list = N'CustomerId,FirstName,LastName,Email,ModifiedDate';
GO
```

Po przełączeniu konsumenta:

```sql
EXEC sys.sp_cdc_disable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer';
GO
```

---

# 4. Zmiana typu danych kolumny

Zmiana typu danych jest bardziej ryzykowna niż zwykłe ADD/DROP COLUMN.

Przykład:

```sql
ALTER TABLE dbo.Customer
ALTER COLUMN Email varchar(500) NULL;
GO
```

CDC rejestruje DDL w historii:

```sql
EXEC sys.sp_cdc_get_ddl_history
    @capture_instance = N'dbo_Customer';
GO
```

W przypadku obsługiwanej zmiany typu danych change table może zostać odpowiednio zmodyfikowana przez proces capture.

Nie wszystkie konwersje są bezpieczne. Zmiany zawężające lub niekompatybilne mogą doprowadzić do błędów procesu capture.

Po każdej zmianie typu danych sprawdź:

```sql
SELECT *
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
GO
```

oraz:

```sql
EXEC sys.sp_cdc_get_ddl_history
    @capture_instance = N'dbo_Customer';
GO
```

---

# 5. Wymiana capture instance — standardowy runbook

To podstawowa procedura dla zmian schematu CDC.

## Krok 1 — zapisz bieżący stan

```sql
DECLARE @OldMinLsn binary(10),
        @OldMaxLsn binary(10);

SET @OldMinLsn = sys.fn_cdc_get_min_lsn(N'dbo_Customer');
SET @OldMaxLsn = sys.fn_cdc_get_max_lsn();

SELECT
    @OldMinLsn AS OldMinLsn,
    @OldMaxLsn AS OldMaxLsn;
GO
```

## Krok 2 — utwórz nową capture instance

```sql
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer_v2',
    @role_name = NULL,
    @supports_net_changes = 1;
GO
```

## Krok 3 — sprawdź kolumny

```sql
EXEC sys.sp_cdc_get_captured_columns
    @capture_instance = N'dbo_Customer_v2';
GO
```

## Krok 4 — sprawdź zakres LSN

```sql
SELECT
    sys.fn_cdc_get_min_lsn(N'dbo_Customer_v2') AS MinLsn,
    sys.fn_cdc_get_max_lsn() AS MaxLsn;
GO
```

## Krok 5 — przełącz konsumenta

Konsument powinien zacząć od punktu, który gwarantuje brak luki pomiędzy starą i nową capture instance.

Nie należy przyjmować „na oko”, że chwila utworzenia nowej capture instance jest wystarczającym watermarkiem.

## Krok 6 — obserwuj obie instancje

```sql
EXEC sys.sp_cdc_help_change_data_capture
    @source_schema = N'dbo',
    @source_name = N'Customer';
GO
```

## Krok 7 — usuń starą capture instance

Dopiero po potwierdzeniu, że konsument korzysta już z nowej:

```sql
EXEC sys.sp_cdc_disable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer';
GO
```

---

# 6. „Re-init od początku” — co to naprawdę oznacza

CDC nie jest mechanizmem snapshotowym.

Włączenie CDC na tabeli nie powoduje utworzenia zdarzeń INSERT dla wszystkich istniejących rekordów.

Jeżeli tabela zawiera 10 milionów istniejących wierszy i dopiero teraz włączymy CDC, CDC przechwyci wyłącznie przyszłe zmiany zapisane w logu od momentu uruchomienia capture.

Dlatego pełna inicjalizacja konsumenta powinna składać się z dwóch elementów:

```text
1. BASELINE / SNAPSHOT istniejących danych
2. CDC dla zmian od uzgodnionego punktu LSN
```

---

# 7. Pełna reinicjalizacja konsumenta

Przykładowy scenariusz:

```text
System docelowy jest uszkodzony
lub
chcemy odtworzyć cały downstream od zera
```

## Krok 1 — zatrzymaj konsumenta

Zatrzymaj Debezium, ETL lub inny proces odczytujący CDC.

## Krok 2 — zapisz punkt synchronizacji

```sql
DECLARE @SnapshotLsn binary(10);
SET @SnapshotLsn = sys.fn_cdc_get_max_lsn();

SELECT @SnapshotLsn AS SnapshotLsn;
GO
```

Ten LSN należy zapisać po stronie procesu inicjalizacyjnego.

## Krok 3 — wykonaj snapshot danych

Przykład:

```sql
SELECT
    CustomerId,
    FirstName,
    LastName,
    Email,
    ModifiedDate
FROM dbo.Customer;
GO
```

Dla realnego systemu snapshot musi być wykonany w sposób zapewniający spójność względem wybranego punktu LSN. Sposób zależy od architektury i wymagań dotyczących blokad/spójności.

## Krok 4 — załaduj snapshot do systemu docelowego

Po zakończeniu baseline konsument przechodzi na CDC.

## Krok 5 — rozpocznij CDC od odpowiedniego LSN

Przy pobieraniu kolejnego zakresu pamiętaj o inkrementacji dolnej granicy, aby nie przetwarzać ostatniego LSN ponownie:

```sql
DECLARE @FromLsn binary(10),
        @ToLsn binary(10);

SET @FromLsn = sys.fn_cdc_increment_lsn(@SnapshotLsn);
SET @ToLsn   = sys.fn_cdc_get_max_lsn();

SELECT @FromLsn, @ToLsn;
GO
```

---

# 8. Twardy reset CDC na tabeli

Jeżeli chcemy całkowicie usunąć historię CDC dla danej tabeli i rozpocząć nową capture instance:

```sql
EXEC sys.sp_cdc_disable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'all';
GO
```

Następnie ponownie włączamy CDC:

```sql
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @role_name = NULL,
    @supports_net_changes = 1;
GO
```

> UWAGA: ta operacja usuwa change tables i funkcje powiązane ze starymi capture instances. Historyczne dane CDC dla tych instancji zostają utracone.

I ponownie: nowa capture instance nie utworzy zdarzeń dla danych, które już istnieją w tabeli.

Jeżeli downstream ma być odtworzony od początku, należy wykonać osobny snapshot/baseline.

---

# 9. Reset CDC dla całej bazy

Operacja destrukcyjna.

Najpierw wyłącz CDC na tabelach albo użyj procedury wyłączającej CDC dla bazy po uprzednim zakończeniu zależności.

```sql
EXEC sys.sp_cdc_disable_db;
GO
```

Następnie:

```sql
EXEC sys.sp_cdc_enable_db;
GO
```

Po tym należy ponownie skonfigurować wszystkie tabele i capture instances.

Nie traktuj tej operacji jako standardowej metody „naprawiania” pojedynczej tabeli.

---

# 10. Sprawdzenie, czy konsument nie wypadł poza retencję

Każdy konsument powinien przechowywać ostatnio przetworzony LSN.

Przykład:

```sql
DECLARE @ConsumerLsn binary(10) = 0x...;
DECLARE @MinLsn binary(10);

SET @MinLsn = sys.fn_cdc_get_min_lsn(N'dbo_Customer');

SELECT
    @ConsumerLsn AS ConsumerLsn,
    @MinLsn      AS MinAvailableLsn,
    CASE
        WHEN @ConsumerLsn < @MinLsn THEN 'REINIT REQUIRED'
        ELSE 'OK'
    END AS Status;
GO
```

Jeżeli watermark konsumenta jest starszy niż `sys.fn_cdc_get_min_lsn`, część zmian została już usunięta przez cleanup job.

Nie da się ich odzyskać z change table.

W takim przypadku potrzebna jest ponowna inicjalizacja downstreamu albo odtworzenie brakujących danych z innego źródła.

---

# 11. Historia DDL

Po każdej zmianie schematu warto sprawdzić:

```sql
EXEC sys.sp_cdc_get_ddl_history
    @capture_instance = N'dbo_Customer';
GO
```

CDC zapisuje informacje m.in. o:

- `ADD COLUMN`,
- `DROP COLUMN`,
- `ALTER COLUMN`.

Pozwala to korelować problemy konsumenta ze zmianami schematu.

---

# 12. Kontrola błędów procesu capture

```sql
SELECT
    session_id,
    phase_number,
    entry_time,
    error_number,
    error_severity,
    error_state,
    error_message,
    start_lsn,
    begin_lsn,
    sequence_value
FROM sys.dm_cdc_errors
ORDER BY entry_time DESC;
GO
```

To jedno z pierwszych miejsc do sprawdzenia po zmianie schematu lub typu danych.

---

# 13. Kontrola sesji CDC

```sql
SELECT *
FROM sys.dm_cdc_log_scan_sessions
ORDER BY session_id DESC;
GO
```

Ważne elementy:

- czas rozpoczęcia i zakończenia skanu,
- liczba przetworzonych rekordów,
- latency,
- empty_scan_count,
- error_count.

---

# 14. Capture job i cleanup job

```sql
EXEC sys.sp_cdc_help_jobs;
GO
```

W `msdb`:

```sql
SELECT *
FROM msdb.dbo.cdc_jobs;
GO
```

Jeżeli capture job nie działa, zmiany nadal mogą pozostawać w transaction log i nie trafiać do change tables.

---

# 15. Nie usuwaj change table ręcznie

Nie wykonuj:

```sql
DROP TABLE cdc.dbo_Customer_CT;
```

Nie usuwaj też ręcznie:

- funkcji `cdc.fn_cdc_get_*`,
- wpisów z `cdc.change_tables`,
- wpisów z `cdc.captured_columns`,
- jobów CDC.

Do zarządzania CDC używaj procedur systemowych:

```text
sys.sp_cdc_enable_db
sys.sp_cdc_disable_db
sys.sp_cdc_enable_table
sys.sp_cdc_disable_table
```

---

# 16. Dwie capture instances — nie tylko dla zmian kolumn

Mechanizm dwóch capture instances warto wykorzystać również przy:

- zmianie `@captured_column_list`,
- zmianie unikalnego indeksu używanego do net changes,
- zmianie sposobu dostępu downstream,
- migracji konsumenta,
- zmianie filegroup dla change table,
- testowaniu nowej wersji integracji.

To pozwala uniknąć hard cutover.

---

# 17. Zmiana Primary Key / unique index

Jeżeli capture instance korzysta z PK albo konkretnego unique index do obsługi net changes, zmiana lub usunięcie tego indeksu wymaga szczególnej ostrożności.

Przed zmianą sprawdź:

```sql
EXEC sys.sp_cdc_help_change_data_capture
    @source_schema = N'dbo',
    @source_name = N'Customer';
GO
```

Pole `index_name` pokazuje indeks używany przez capture instance.

Przy zmianie klucza praktycznie bezpieczniejszą procedurą jest utworzenie nowej capture instance z właściwym indeksem.

Przykład:

```sql
EXEC sys.sp_cdc_enable_table
    @source_schema = N'dbo',
    @source_name = N'Customer',
    @capture_instance = N'dbo_Customer_v2',
    @role_name = NULL,
    @supports_net_changes = 1,
    @index_name = N'UX_Customer_ExternalId';
GO
```

Kolumny indeksu identyfikującego muszą być uwzględnione w przechwytywanych kolumnach.

---

# 18. RENAME kolumny lub tabeli

Operacje zmiany nazw są szczególnie niebezpieczne dla integracji CDC, ponieważ kontrakt downstream zwykle opiera się na nazwach capture instance, funkcji i kolumn.

Nie należy traktować rename jako przezroczystej zmiany.

Zalecenie:

1. utworzyć nową strukturę/capture instance,
2. przełączyć konsumenta,
3. dopiero potem wycofać starą strukturę.

---

# 19. Partition SWITCH

Jeżeli tabela korzysta z partycjonowania, należy zweryfikować `@allow_partition_switch`.

`SWITCH PARTITION` może przenosić dane w sposób, który nie generuje zwykłego zestawu zmian oczekiwanego przez konsumenta CDC.

Przed użyciem SWITCH na tabeli CDC należy jednoznacznie zweryfikować zachowanie w danej architekturze i scenariuszu konsumenta.

---

# 20. TRUNCATE TABLE

CDC opiera się na zmianach możliwych do odwzorowania z transaction log do change table.

`TRUNCATE TABLE` nie powinien być traktowany jak miliony operacji DELETE widoczne w CDC.

Jeżeli downstream musi otrzymać informację o usunięciu każdego rekordu, preferuj kontrolowany `DELETE` lub osobny mechanizm biznesowy/synchronizacyjny.

To koniecznie należy przetestować w POC przed użyciem produkcyjnym.

---

# 21. Retencja a maintenance window

Przed większym wdrożeniem, przestojem Debezium lub ETL sprawdź retencję:

```sql
EXEC sys.sp_cdc_help_jobs;
GO
```

Jeżeli planowany downtime może być dłuższy niż retencja, tymczasowo zwiększ retencję zanim konsument zostanie zatrzymany.

Po zakończeniu prac przywróć docelową wartość.

Nie zwiększaj retencji bezterminowo — rosną change tables i koszt cleanup.

---

# 22. Backup / restore i CDC

Przy scenariuszach DR należy zawsze sprawdzić, czy po restore CDC pozostaje aktywne zgodnie z oczekiwaniem oraz czy downstreamowy watermark nadal odpowiada dostępnemu zakresowi LSN.

Po restore sprawdź:

```sql
SELECT
    name,
    is_cdc_enabled
FROM sys.databases
WHERE name = DB_NAME();
GO

EXEC sys.sp_cdc_help_change_data_capture;
GO
```

Następnie zweryfikuj `min_lsn` i `max_lsn` przed ponownym uruchomieniem konsumenta.

---

# 23. Nie zakładaj, że MAX_LSN oznacza „wszystko już jest w CDC”

CDC działa asynchronicznie.

W systemie może istnieć krótki okres pomiędzy COMMIT transakcji a pojawieniem się wpisu w change table.

Przy projektowaniu własnego konsumenta zakresy LSN należy obsługiwać zgodnie z funkcjami CDC, a nie na podstawie czasu zegarowego aplikacji.

---

# 24. Checklista przed wdrożeniem zmiany DDL na produkcji

```text
[ ] Czy tabela ma jedną czy dwie capture instances?
[ ] Czy downstream używa all changes czy net changes?
[ ] Jaki jest ostatni LSN konsumenta?
[ ] Jaki jest aktualny min_lsn?
[ ] Czy retencja obejmuje całe planowane okno prac?
[ ] Czy zmiana dotyczy kolumny przechwytywanej?
[ ] Czy zmienia się PK / unique index?
[ ] Czy zmienia się typ danych?
[ ] Czy downstream obsługuje nowy schemat?
[ ] Czy możliwa jest migracja przez drugą capture instance?
[ ] Czy istnieje plan rollback?
[ ] Czy po wdrożeniu sprawdzimy sys.dm_cdc_errors?
[ ] Czy po wdrożeniu sprawdzimy sys.dm_cdc_log_scan_sessions?
[ ] Czy wykonano test INSERT / UPDATE / DELETE?
```

---

# 25. Zalecany wzorzec zmian schematu

Najbezpieczniejszy model:

```text
SOURCE TABLE
     |
     +--> CDC v1 --> Consumer v1
     |
     +--> CDC v2 --> Consumer v2

              test
               |
               v

SOURCE TABLE
     |
     +--> CDC v2 --> Consumer v2
```

Czyli:

```text
Expand -> Migrate -> Contract
```

1. **Expand** — dodaj nową strukturę/capture instance.
2. **Migrate** — uruchom i zweryfikuj nowego konsumenta.
3. **Contract** — usuń starą capture instance.

To jest preferowany sposób zmian w CDC, szczególnie gdy downstream działa 24/7.

---

# 26. Co warto dodatkowo przetestować w naszym POC

W SQLLab powinniśmy osobno wykonać scenariusze:

1. dodanie kolumny przy aktywnej CDC,
2. utworzenie drugiej capture instance,
3. równoległy odczyt obu capture instances,
4. usunięcie kolumny,
5. zmiana typu danych,
6. zmiana PK / unique index,
7. zatrzymanie capture job,
8. wygenerowanie backlogu,
9. restart capture job,
10. wymuszenie sytuacji, w której konsument wypada poza retencję,
11. reinicjalizacja konsumenta,
12. twardy reset capture instance,
13. pełny snapshot + CDC delta,
14. TRUNCATE TABLE,
15. partition switch, jeżeli użyjemy tabeli partycjonowanej,
16. backup/restore bazy z CDC,
17. restart SQL Server Agent,
18. restart instancji SQL Server,
19. zmiana schematu podczas backlogu,
20. później ten sam zestaw testów z Debezium.

---

# 27. Najważniejsze zasady operacyjne

1. CDC nie jest snapshotem.
2. Nie zakładaj, że dodana kolumna automatycznie pojawi się w starej capture instance.
3. Nie kasuj obiektów CDC ręcznie.
4. Do zmian schematu preferuj drugą capture instance.
5. Zawsze zapisuj watermark/LSN konsumenta.
6. Monitoruj `min_lsn`, żeby wykryć utratę zmian przez cleanup.
7. Po zmianie typu danych sprawdzaj `sys.dm_cdc_errors`.
8. Retencja musi być dłuższa niż maksymalny realny downtime konsumenta.
9. Re-init downstreamu = baseline/snapshot + CDC delta.
10. Disable/enable CDC nie odtwarza historycznych wierszy.
11. Nie wykonuj dużych zmian DDL bez planu dla downstreamu.
12. Przy krytycznych integracjach traktuj schemat CDC jak kontrakt API.

---

# Dokumentacja Microsoft

- `sys.sp_cdc_enable_table`
- `sys.sp_cdc_disable_table`
- `sys.sp_cdc_help_change_data_capture`
- `sys.sp_cdc_get_captured_columns`
- `sys.sp_cdc_get_ddl_history`
- `sys.fn_cdc_get_min_lsn`
- `sys.fn_cdc_get_max_lsn`
- `sys.fn_cdc_increment_lsn`
- `sys.dm_cdc_errors`
- `sys.dm_cdc_log_scan_sessions`
- `cdc.change_tables`
- `cdc.captured_columns`

Dokument należy traktować jako runbook operacyjny i każdą istotną zmianę schematu najpierw przećwiczyć w SQLLab.
