# SQL Server a blokady przy `XLOCK, ROWLOCK` — co można zrobić po stronie bazy

## Sytuacja

Aplikacja wymusza hinty:

```sql
WITH (XLOCK, ROWLOCK)
```

To oznacza, że SQL Server ma założyć **blokady ekskluzywne** i trzymać je **do końca transakcji**. Jeśli `XLOCK` jest użyty razem z `ROWLOCK`, blokada ekskluzywna ma dotyczyć poziomu wiersza (o ile silnik może utrzymać taką granularność). To zachowanie jest zgodne z dokumentacją i nie jest „błędem silnika”. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17))

## Najważniejszy wniosek

Jeśli aplikacja wymusza `XLOCK`, to **nie ma jednego magicznego parametru SQL Server, który wyłączy skutki tego hintu**. SQL Server ma taki hint honorować. Można jedynie **zmniejszyć promień rażenia**, a nie usunąć przyczynę. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17))

---

## Co realnie można zrobić po stronie SQL Server

### 1. Skrócić czas trzymania transakcji

To jest najważniejsza i najskuteczniejsza rzecz. Microsoft zaleca przy problemach z blokowaniem i eskalacją blokad utrzymywać **krótkie transakcje** i zmniejszać zakres blokowanych danych. Im krócej trwa transakcja, tym krócej trzymany jest `XLOCK`. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

W praktyce oznacza to:

- nie trzymać otwartej transakcji dłużej niż trzeba,
- nie robić dodatkowej logiki aplikacyjnej w otwartej transakcji,
- nie dodawać sztucznych opóźnień (`WAITFOR`) w trakcie trzymania locka,
- rozbijać duże operacje na mniejsze batche. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

---

### 2. Poprawić indeksy, żeby zapytania kończyły się szybciej

Jeśli zapytanie z `XLOCK` trafia dokładnie w potrzebne wiersze (seek), zamiast skanować dużą część tabeli, to:

- szybciej znajduje dane,
- krócej trzyma lock,
- obejmuje mniejszy zakres zasobów. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

To zwykle oznacza:

- indeks pod kolumny z `WHERE`,
- indeksy pod kolumny używane w joinach,
- ograniczenie skanów i kosztownych lookupów. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

---

### 3. Sprawdzić, czy dochodzi do **lock escalation**

Nie każde blokowanie to eskalacja. Microsoft wprost wskazuje, że najpierw trzeba sprawdzić, czy problemem jest właśnie **eskalacja blokad**. Najprościej zrobić to przez Extended Events z eventem `lock_escalation`. Jeśli nie ma takich zdarzeń, to eskalacja nie jest głównym winowajcą. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

Dokumentacja mówi też, że blokowanie jest naturalnym skutkiem działania silnika lock-based i samo w sobie nie oznacza od razu eskalacji. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/understand-resolve-blocking?utm_source=chatgpt.com))

---

### 4. Rozważyć ustawienie `LOCK_ESCALATION` na konkretnej tabeli

Na poziomie tabeli można użyć opcji `LOCK_ESCALATION`, np.:

```sql
ALTER TABLE dbo.TwojaTabela
SET (LOCK_ESCALATION = DISABLE);
```

Opcja ta pozwala wpływać na sposób eskalacji blokad dla danej tabeli. Dokumentacja `ALTER TABLE` potwierdza, że można użyć ustawień `AUTO`, `TABLE` i `DISABLE`. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-transact-sql?view=sql-server-ver17))

**Uwaga:** to nie jest cudowne lekarstwo. Wyłączenie eskalacji może zwiększyć liczbę drobnych locków, a więc także koszt pamięci i zarządzania lockami. To trzeba testować ostrożnie i tylko dla konkretnych „gorących” tabel. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

Aktualne ustawienie można sprawdzić tak:

```sql
SELECT
    name,
    lock_escalation_desc
FROM sys.tables
WHERE name = N'TwojaTabela';
```

Kolumna `lock_escalation_desc` pokazuje ustawienie dla tabeli. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-transact-sql?view=sql-server-ver17))

---

### 5. Użyć `SET LOCK_TIMEOUT`, jeśli lepszy jest szybki błąd niż długie czekanie

`SET LOCK_TIMEOUT` **nie zmniejsza liczby blokad**. Ono jedynie ustawia maksymalny czas oczekiwania na zablokowany zasób. Jeśli czas zostanie przekroczony, SQL Server anuluje zablokowane polecenie i zwróci błąd. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-lock-timeout-transact-sql?view=sql-server-ver17))

Przykład:

```sql
SET LOCK_TIMEOUT 5000;
```

To oznacza, że polecenie poczeka maksymalnie 5 sekund. Domyślnie wartość wynosi `-1`, czyli czekanie bez limitu dla danej sesji. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-lock-timeout-transact-sql?view=sql-server-ver17))

To nie rozwiązuje problemu źródłowego, ale może ograniczyć długie „wisy” aplikacji.

---

### 6. Nie traktować parametru serwera `locks` jako rozwiązania

Opcja serwera `sp_configure 'locks'` dotyczy liczby locków i pamięci dla struktur locków. To **nie jest ustawienie służące do zmniejszania blokowania**. Standardowo SQL Server sam zarządza tym dynamicznie i zwykle tak powinno zostać. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-locks-server-configuration-option?view=sql-server-ver17))

---

## Czego raczej nie robić bez mocnego uzasadnienia

### Globalne wyłączanie eskalacji przez trace flagi

Microsoft opisuje możliwość wpływania na eskalację globalnie, ale jednocześnie wyraźnie zaznacza, że eskalacja istnieje po coś i jej globalne wyłączanie może pogorszyć zużycie zasobów. To nie jest bezpieczny „domyślny fix”. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

### Liczenie, że `ROWLOCK` uratuje współbieżność

`ROWLOCK` to wskazówka co do granularności. Nie oznacza automatycznie „będzie lekko i bezpiecznie”. Jeśli aplikacja wymusza `XLOCK`, to nadal jest to blokada ekskluzywna, tylko na poziomie wiersza, jeśli silnik może to utrzymać. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17))

### Oczekiwanie, że optymalizator „obejdzie” hint

Hinty locków ograniczają elastyczność silnika. Microsoft w dokumentacji optimized locking wprost zaznacza, że hinty takie jak `XLOCK`, `UPDLOCK` czy `HOLDLOCK` zmniejszają korzyści z mechanizmów optymalizacji blokowania, bo wymuszają określone zachowanie. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/relational-databases/performance/optimized-locking?view=sql-server-ver17))

---

## Najrozsądniejsza strategia DBA, gdy aplikacja używa `XLOCK`

### Krok 1 — zmierzyć problem
Sprawdź:

- kto blokuje,
- kto czeka,
- jaki jest `wait_type`,
- czy występuje `lock_escalation`. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

### Krok 2 — skrócić czas trzymania locków
Najpierw:

- indeksy,
- lepsze plany,
- mniejsze batche,
- krótsze transakcje. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

### Krok 3 — sprawdzić jedną konkretną tabelę
Jeśli jedna tabela jest „gorąca”, można testowo rozważyć:

- `LOCK_ESCALATION = DISABLE`

ale tylko po wcześniejszym pomiarze. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-transact-sql?view=sql-server-ver17))

### Krok 4 — ewentualnie ustawić `LOCK_TIMEOUT`
Jeśli biznesowo lepszy jest szybki timeout niż długie oczekiwanie. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-lock-timeout-transact-sql?view=sql-server-ver17))

---

## Dokumentacja Microsoft Learn

### Table hints (`XLOCK`, `ROWLOCK`, `UPDLOCK`, `HOLDLOCK`)
Opis działania hintów tabelowych, w tym `XLOCK` i jego zachowanie do końca transakcji. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17))

### Resolve blocking problems caused by lock escalation
Jak sprawdzić, czy problemem jest eskalacja blokad i jak do niej podejść. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

### Understand and resolve SQL Server blocking problems
Ogólna dokumentacja o blokowaniu, przyczynach i sposobie diagnostyki. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/understand-resolve-blocking?utm_source=chatgpt.com))

### ALTER TABLE — `LOCK_ESCALATION`
Składnia i opcje konfiguracji eskalacji blokad na poziomie tabeli. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/alter-table-transact-sql?view=sql-server-ver17))

### SET LOCK_TIMEOUT
Jak ustawić maksymalny czas oczekiwania na lock. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/statements/set-lock-timeout-transact-sql?view=sql-server-ver17))

### Optimized locking
Wyjaśnienie, że hinty locków ograniczają korzyści z nowszych optymalizacji blokowania. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/relational-databases/performance/optimized-locking?view=sql-server-ver17))

### Server configuration option `locks`
Opis opcji serwera `locks` i dlaczego nie jest to narzędzie do redukcji blokowania. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-locks-server-configuration-option?view=sql-server-ver17))

---

## Podsumowanie

Jeżeli nie możesz użyć RCSI i aplikacja wymusza `XLOCK, ROWLOCK`, to po stronie SQL Server możesz głównie:

- **skracać transakcje**,
- **przyspieszać zapytania indeksami**,
- **sprawdzać i ograniczać eskalację blokad**,
- **ewentualnie stosować `LOCK_TIMEOUT`**, jeśli lepszy jest szybki błąd niż długie czekanie. ([learn.microsoft.com](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/resolve-blocking-problems-caused-lock-escalation?utm_source=chatgpt.com))

Nie usuniesz źródła problemu bez zmiany kodu aplikacji, ale możesz znacząco ograniczyć skalę blokowania. ([learn.microsoft.com](https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17))
