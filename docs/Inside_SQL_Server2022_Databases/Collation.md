# Collation — wyjaśnienie, zmiana i problemy praktyczne

## Co to jest *collation*?
**Collation** określa reguły porównywania i sortowania tekstu w SQL Server. Decyduje o:
- porównaniu wielkości liter (CI — case insensitive vs CS — case sensitive),
- rozróżnianiu znaków akcentowanych (AI vs AS),
- porządku sortowania (locale / sort sequence),
- dla `VARCHAR` — jakie kodowanie / code page jest używane (dla `NVARCHAR` - Unicode, ale reguły sortowania nadal zależą od collation),
- opcjonalnie wsparciu UTF-8 (od SQL Server 2019: collations z sufiksem `_UTF8` pozwalają na `VARCHAR` przechowujący UTF-8).

Przykłady nazw collations:
- `SQL_Latin1_General_CP1_CI_AS` — klasyczna „SQL collation” (SQL sort order), Case-Insensitive, Accent-Sensitive.
- `Latin1_General_100_CI_AS_SC_UTF8` — nowy Windows collation (100 = sort order), Case-Insensitive, Accent-Sensitive, Supplementary Characters (SC), UTF8 dla `VARCHAR`.

> Uwaga: Windows collations (np. `Latin1_General_100_...`) są zalecane dla nowych wdrożeń. Collations SQL (prefiks `SQL_`) to starsze porządki sortowania.

---

## Gdzie collation występuje (poziomy)
1. **Server / instance collation** — domyślny collation dla serwera; używany do tworzenia kolacji katalogów systemowych i `tempdb`.
2. **Database collation** — domyślny collation bazy danych; stosowany przy tworzeniu nowych kolumn bez jawnej kolacji, metadanych bazy, a także przy domyślnych collation obiektów bazy.
3. **Column collation** — każdy znakowy typ kolumny (`CHAR`, `VARCHAR`, `TEXT`, `NCHAR`, `NVARCHAR`, `NTEXT`) może mieć własną kolację; jeśli nie — użyje kolacji domyślnej bazy w której kolumna powstaje.
4. **Expression / query collation** — możesz zadeklarować collation przy porównaniu lub konwersji za pomocą klauzuli `COLLATE`.
5. **tempdb collation** — *zawsze* przyjmuje wartość collation instancji serwera (tzn. collation serwera ustalone przy instalacji).

---

## Jak sprawdzić aktualne collation
```sql
-- collation instancji (server)
SELECT SERVERPROPERTY('Collation') AS ServerCollation;

-- collations wszystkich baz
SELECT name, collation_name
FROM sys.databases
ORDER BY name;

-- collation bieżącej bazy
SELECT DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS DatabaseCollation;

-- kolumny z collation w konkretnej tabeli
SELECT c.name, c.collation_name
FROM sys.columns c
WHERE c.object_id = OBJECT_ID('dbo.YourTable') AND c.collation_name IS NOT NULL;
```

---

## Zmiana collation na poziomie bazy danych
### `ALTER DATABASE` — zmienia domyślną kolację bazy
```sql
ALTER DATABASE YourDB COLLATE Latin1_General_100_CI_AS_SC; 
-- zmienia *domyślny* collation bazy (wpływa na nowe obiekty)
```
**Important:** `ALTER DATABASE ... COLLATE` **nie** zmienia automatycznie collation istniejących kolumn znakowych. Aby zmienić kolację kolumn, trzeba je jawnie zmodyfikować (patrz niżej).

### Zmiana collation kolumn znakowych
Aby zmienić collation kolumny:
1. Jeśli kolumna jest częścią indeksu/PK/unikalnego ograniczenia — usuń indeks/constraint lub zmodyfikuj go (konieczność planowania).
2. Wykonaj `ALTER TABLE ... ALTER COLUMN` z nową kolacją:

```sql
ALTER TABLE dbo.YourTable
ALTER COLUMN Name NVARCHAR(200) COLLATE Latin1_General_100_CI_AS NOT NULL;
```

- Musisz powtórnie zbudować indeksy, constraints, statystyki; dla dużych tabel może to trwać i wymagać miejsca na tempdb/IO.
- Dla typów `VARCHAR` trzeba zwrócić uwagę na zmianę code page (możliwa utrata danych przy zmianie na niekompatybilny code page).

### Skrypt pomocniczy: wygenerowanie ALTER dla wszystkich kolumn
Przykład, który generuje polecenia `ALTER TABLE` (trzeba ostrożnie przeglądnąć i wykonać w oknach maintenance):
```sql
SELECT 'ALTER TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) + 
       ' ALTER COLUMN ' + QUOTENAME(c.name) + ' ' + 
       CASE WHEN ty.name IN ('nchar','nvarchar') 
            THEN ty.name + '(' + 
                 CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length/2 AS VARCHAR(10)) END + ')'
            ELSE ty.name + '(' + CASE WHEN c.max_length = -1 THEN 'MAX' ELSE CAST(c.max_length AS VARCHAR(10)) END + ')' END +
       ' COLLATE Latin1_General_100_CI_AS ' +
       CASE WHEN c.is_nullable = 1 THEN ' NULL;' ELSE ' NOT NULL;' END AS AlterStmt
FROM sys.columns c
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
JOIN sys.tables t ON c.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE c.collation_name IS NOT NULL
  AND c.collation_name <> 'Latin1_General_100_CI_AS';
```
> Przed wykonaniem: zrób backup, sprawdź zależności, i przetestuj na środowisku dev.

---

## Zmiana collation na poziomie instancji (server-level)
**Zmiana collation serwera** wymaga zbudowania/odb odbudowy systemowych baz danych — to **operacja inwazyjna** z przestojem.

### Metody:
1. **Rebuild system databases** (najczęstsza metoda) — użyj instalatora `setup.exe` z akcją `REBUILDDATABASE` i podaj nową kolację:
   - Przykład:
     ```bat
     Setup.exe /QUIET /ACTION=REBUILDDATABASE /INSTANCENAME=MSSQLSERVER 
               /SQLSYSADMINACCOUNTS="DOMAIN\Admins" 
               /SQLCOLLATION="Latin1_General_100_CI_AS_SC" 
               /IAcceptSQLServerLicenseTerms
     ```
   - `REBUILDDATABASE` tworzy nowe systemowe bazy (`master`, `model`, `msdb`, `tempdb`) z nową kolacją.
2. **Reinstall SQL Server** — odinstaluj i zainstaluj z wybraną kolacją (również wymaga więcej pracy).

### Co trzeba przygotować i uwzględnić:
- **Pełny backup** wszystkich baz użytkownika (FULL + LOG).  
- **Zescriptować/wyeksportować**: loginy (`sp_help_revlogin`), joby Agent, linked servers, certyfikaty, endpoints, role serwera, logowanie serwera, itp. Rebuild nadpisuje/master i msdb, więc te obiekty trzeba odtworzyć po operacji.
- Zaplanuj **downtime** — operacja wymaga zatrzymania serwera i czasu na odtworzenie konfiguracji.
- Po rebuild: odtwórz loginy (powiązania SID), joby, i inne obiekty oraz sprawdź działanie aplikacji.
- `tempdb` otrzyma nowy collation równy collation serwera po odbudowie — to wpływa na wszelkie temp tables.

> **WAŻNE:** nie ma „online” przełącznika pozwalającego bezboleśnie zmienić server collation. To istotne przerwanie.

---

## `tempdb` i różnica collations między bazą użytkownika a `tempdb`
- `tempdb` zawsze używa **server collation** (ustalonego przy instalacji / rebuild).
- Jeśli Twoja **baza aplikacyjna** ma inną kolację niż `tempdb`, to kolumny tworzone w `tempdb` (np. kolumny w tabelach tymczasowych `#temp`, `##temp`, czy zmienne tabelowe) będą miały collation `tempdb` — co może skutkować konfliktami podczas porównań/sortowania pomiędzy kolumnami z użytkowej bazy i tymczasowych.

### Typowy scenariusz problemowy
- Baza `AppDB` ma collation `Latin1_General_CI_AS`.
- Server/`tempdb` ma `SQL_Latin1_General_CP1_CI_AS`.
- Tworzysz w `AppDB` tabelę z kolumną `Name NVARCHAR(100)` (kolacja `Latin1_General_CI_AS`) i #temp bez jawnej kolacji (czyli kolacja dla kolumny w #temp = `tempdb` = `SQL_Latin1_General_CP1_CI_AS`).
- Przy próbie `JOIN`/`WHERE` po tych kolumnach dostaniesz błąd kolacji.

### Przykład — scenariusz i błąd
```sql
USE AppDB; -- AppDB collation = Latin1_General_CI_AS (przykład)
GO

CREATE TABLE dbo.Person (Name NVARCHAR(100));
INSERT INTO dbo.Person (Name) VALUES (N'Łukasz');

-- Tworzysz tymczasową tabelę bez określenia COLLATE:
CREATE TABLE #tmp (Name NVARCHAR(100));  -- kolacja = tempdb collation (np. SQL_Latin1_General_CP1_CI_AS)
INSERT INTO #tmp (Name) VALUES (N'Łukasz');

-- Teraz spróbuj JOIN:
SELECT p.Name, t.Name
FROM dbo.Person p
JOIN #tmp t ON p.Name = t.Name;
```
Błąd:
```
Msg 468, Level 16, State 9, Line XX
Cannot resolve the collation conflict between "SQL_Latin1_General_CP1_CI_AS" and "Latin1_General_CI_AS" in the equal to operation.
```

---

## Jak rozwiązać konflikt collations — opcje
1. **Utworzyć tymczasową tabelę z jawnie dobraną kolacją** (dopasowaną do kolacji tabeli docelowej):
```sql
CREATE TABLE #tmp (Name NVARCHAR(100) COLLATE Latin1_General_CI_AS);
```

2. **Użyć `COLLATE` w zapytaniu** (jednokrotne rozwiązanie):
```sql
SELECT p.Name, t.Name
FROM dbo.Person p
JOIN #tmp t ON p.Name COLLATE SQL_Latin1_General_CP1_CI_AS = t.Name;
```

3. **Tworzyć #temp przez `SELECT INTO` z tabeli źródłowej** — wtedy kolumny tymczasowej tabeli odziedziczą collation kolumn źródłowych:
```sql
SELECT Name INTO #tmp FROM dbo.Person WHERE 1 = 0;  -- struktura zachowuje collation kolumny 'Name' z dbo.Person
```

4. **Zmienić kolację kolumn docelowych** (dłuższe, trwałe) — `ALTER TABLE ... ALTER COLUMN ... COLLATE` (wymaga planowania przy indeksach).

5. **Zmienic server collation (rebuild system DB)** — jeżeli chcesz, żeby `tempdb` miał kolację jak twoje bazy (ale to poważna operacja z dużym downtime i koniecznością odtworzenia obiektów systemowych).

6. **Użyć NVARCHAR i unikać VARCHAR** — `NVARCHAR` używa Unicode; mimo że nadal ma kolation do sortowania, zmniejsza problemy z code page; jednak kolation conflict nadal może wystąpić dla NVARCHAR (bo collation wpływa na porównania i sortowanie).

---

## Implicit conversion a collation
- SQL Server **nie** dokonuje „implicit collation conversion” w taki sposób, żeby pozbyć się konfliktu — zamiast tego zgłasza błąd kolacji przy próbie bezpośredniego porównania różnych collation.
- Jedyną „implicit conversion”, o której warto pamiętać, jest konwersja między typami znakowymi (VARCHAR vs NVARCHAR) — tam SQL dokona konwersji typów (np. VARCHAR → NVARCHAR) zgodnie z regułami typów, ale **nie** zmieni collation automatycznie.

---

## Wpływ collation i encodingu na rozmiar danych (VARCHAR vs NVARCHAR / UTF-8 / code pages)

### Zasady (skrótowo)
- `VARCHAR(n)` — **n** definiuje rozmiar w **bajtach**. Dla *jednobajtowych* code page (np. Latin1 / CP1252) oznacza to też **n znaków**. Dla *wielobajtowych* kodowań (DBCS) lub UTF-8, jeden znak może zajmować 1..N bajtów, więc liczba **znaków** ≤ n (zależnie od znaków).
- `NVARCHAR(n)` — **n** definiuje maksymalną liczbę **znaków** (nie dosłownie bajtów) ale jest implementowane jako pary bajtów (UTF-16/ UCS-2). W praktyce SQL Server alokuje do 2 bajtów na BMP-znak; znaki supplementary (poza BMP) używają surrogate pairs (4 bajty).
- `VARCHAR` + `_UTF8` collation (SQL Server 2019+) — `VARCHAR` przechowuje UTF-8 bytes: 1–4 bajty na znak (1 dla ASCII/łacińskich, 2 dla wielu akcentowanych, 3 dla większości znaków, 4 dla suplementarnych emoji).

### Przykłady (intuicyjne)
- `VARCHAR(50)` przy **Latin1/CP1252** → maksymalnie **50 znaków**, maks. **50 bajtów**.
- `VARCHAR(50)` przy **DBCS** (np. japoński Shift-JIS) → jeśli wszystkie znaki są 2-bajtowe → maks. **25 znaków**.
- `VARCHAR(50)` z **UTF-8** collation → najgorszy przypadek (4-bajtowe znaki) → ⌊50/4⌋ = **12 znaków**.
- `NVARCHAR(50)` → zwykle miejsce na **50 BMP-znaków** (≈100 bajtów). Jeśli wszystkie znaki są supplementary → maks. **25 znaków** (bo zajmują 4 bajty każdy).

### Jak to sprawdzić w praktyce — gotowe SQL testy
```sql
-- 1) DATALENGTH vs LEN dla VARCHAR (Latin1)
DECLARE @s1 varchar(50) COLLATE Latin1_General_100_CI_AS = 'abcd';
DECLARE @s2 varchar(50) COLLATE Latin1_General_100_CI_AS = N'Łąka';
SELECT LEN(@s1) AS len_s1, DATALENGTH(@s1) AS bytes_s1,
       LEN(@s2) AS len_s2, DATALENGTH(@s2) AS bytes_s2;

-- 2) VARCHAR z UTF-8 collation (SQL Server 2019+)
DECLARE @u1 varchar(50) COLLATE Latin1_General_100_CI_AS_SC_UTF8 = 'a';        -- 1 byte
DECLARE @u2 varchar(50) COLLATE Latin1_General_100_CI_AS_SC_UTF8 = 'ñ';       -- 2 bytes in UTF-8
DECLARE @u3 varchar(50) COLLATE Latin1_General_100_CI_AS_SC_UTF8 = N'😊';     -- emoji -> 4 bytes in UTF-8
SELECT @u1 AS sample, LEN(@u1) AS chars, DATALENGTH(@u1) AS bytes
UNION ALL
SELECT @u2, LEN(@u2), DATALENGTH(@u2)
UNION ALL
SELECT @u3, LEN(@u3), DATALENGTH(@u3);

-- 3) NVARCHAR i surrogate pairs
DECLARE @n1 nvarchar(50) = N'a';       -- 1 char, 2 bytes
DECLARE @n2 nvarchar(50) = N'ą';       -- 1 char, 2 bytes
DECLARE @n3 nvarchar(50) = N'😊';      -- supplementary char, may count as 2 code units
SELECT @n1 AS sample, LEN(@n1) AS LEN_chars, DATALENGTH(@n1) AS bytes
UNION ALL
SELECT @n2, LEN(@n2), DATALENGTH(@n2)
UNION ALL
SELECT @n3, LEN(@n3), DATALENGTH(@n3);
```

**Czego oczekiwać w wynikach**
- `DATALENGTH()` zwraca liczbę **bajtów**.
- `LEN()` zwraca liczbę **znaków** (ale LEN może raportować 2 dla surrogate pairs w niektórych kontekstach — testuj na swojej wersji).
- Przy `VARCHAR` + UTF-8: `DATALENGTH` może być > `LEN` (bo zmienna liczba bajtów na znak).
- Przy `NVARCHAR`: zwykle `DATALENGTH = 2 * LEN` dla BMP-znaków; dla supplementary `DATALENGTH` rośnie odpowiednio (4 bajty na taki znak).

---

## Jak to wpływa na projekt tabel / indeksów
- `VARCHAR(n)` — **n** to limit bajtów → indeksy, klucze i rozmiar wiersza musisz planować pod kątem bajtów. Jeżeli spodziewasz się wielobajtowych znaków (DBCS/UTF-8), zarezerwuj większe `n` lub użyj `NVARCHAR`.
- `NVARCHAR` zajmuje **z reguły więcej miejsca** (2 bajty na BMP znak), ale bezpiecznie obsługuje wiele języków bez problemów z code page. Dla aplikacji wielojęzycznych **NVARCHAR** jest zwykle rekomendowane.
- Przy użyciu **UTF-8 collations** możesz oszczędzić miejsce w `VARCHAR` dla dominującego alfabetu łacińskiego (angielski → 1 bajt), ale pamiętaj o zmiennej długości i najgorszych przypadkach (emoji/supplementary → 4 bajty).

---

## Przykładowe obliczenia „popychające palcem”
- Chcesz przewidzieć ile znaków może wejść w `VARCHAR(100)`:
  - jeśli code page = single byte → do 100 znaków;
  - jeśli DBCS 2-byte max → w najgorszym przypadku ⌊100/2⌋ = 50 znaków;
  - jeśli UTF-8 worst-case 4 bytes → ⌊100/4⌋ = 25 znaków.
- Dla `NVARCHAR(100)`: zwykle 100 BMP-znaków (≈200 bajtów). Jeśli wszystkie znaki są supplementary → ⌊100/2⌋ = 50 takich znaków.

---

## Rekomendacje i dobre praktyki
1. **Jeżeli aplikacja obsługuje wiele języków / emoji / znaki spoza BMP** → używaj **NVARCHAR** z collations SC (albo nowszych collations wspierających supplementary chars).  
2. **Jeżeli Twoje dane są głównie łacińskie i zależy Ci na oszczędności miejsca** → rozważ `VARCHAR` z **UTF-8 collation** (SQL Server 2019+), ale testuj zapotrzebowanie bajtowe (zwłaszcza gdy aplikacja może przyjmować emoji).  
3. **Przy planowaniu indeksów** miej świadomość limitów klucza i limitów rozmiaru wiersza (liczone w bajtach).  
4. Zawsze mierzyć `DATALENGTH()` w testach obciążeniowych, by wyczuć rzeczywiste zużycie miejsca.

---

## Szybka ściąga (cheat sheet)
- Sprawdź server collation: `SELECT SERVERPROPERTY('Collation')`
- Sprawdź collation bazy: `SELECT collation_name FROM sys.databases WHERE name = DB_NAME();`
- Zmień domyślną collation bazy: `ALTER DATABASE YourDB COLLATE <New_Collation>;`
- Zmień kolumnę: `ALTER TABLE T ALTER COLUMN C NVARCHAR(100) COLLATE <New_Collation> [NULL|NOT NULL];`
- Jeśli `tempdb` koliduje z DB: utwórz #temp z jawnym `COLLATE` lub użyj `SELECT INTO` aby zachować collation źródła.
- Aby zmienić collation serwera: **rebuild system databases** (downtime, skrypt backup + odtworzenie logins/jobs).

---

## Przydatne przykłady (podsumowanie)
### 1) Sprawdź różnicę `server` vs `db` vs `tempdb`
```sql
SELECT 'server' AS what, SERVERPROPERTY('Collation') AS col;
SELECT name, collation_name FROM sys.databases WHERE name IN (DB_NAME(), 'tempdb');
```

### 2) Przykład rozwiązania konfliktu w zapytaniu
```sql
-- użyj COLLATE po stronie, która chcesz zmienić w locie
SELECT p.Name, t.Name
FROM dbo.Person p
JOIN #tmp t
  ON p.Name COLLATE SQL_Latin1_General_CP1_CI_AS = t.Name;
```

### 3) Utworzenie #temp z kolacją zgodną z tabelą źródłową (SELECT INTO)
```sql
SELECT Name INTO #tmp FROM dbo.Person WHERE 1 = 0; -- kolacja kolumny #tmp.Name = kolacja dbo.Person.Name
```

### 4) Zmiana server collation — przykładowe kroki (plan działania)
1. Pełny backup wszystkich baz (FULL + LOG).  
2. Zaplanuj downtime.  
3. Wygeneruj skrypty logins (`sp_help_revlogin`) i jobów Agent.  
4. Uruchom rebuild system DB (setup.exe /ACTION=REBUILDDATABASE /SQLCOLLATION="NowaKolacja" ...).  
5. Odtwórz loginy, joby, linked servers, certyfikaty.  
6. Przetestuj aplikacje.

---

_ostatnia aktualizacja: 2025-09-17_
