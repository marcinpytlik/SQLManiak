# SQL Lock Simulator V3 - instrukcja uruchomienia i gotowe profile testow

## Cel tego dokumentu

Ten dokument pokazuje krok po kroku, jak:

- przygotowac projekt w VS Code
- uruchomic narzedzie
- skonfigurowac polaczenie do SQL Server
- korzystac z gotowych profili testowych
- analizowac wyniki po przebiegu

To jest praktyczna instrukcja warsztatowa, zeby szybko przejsc od pustego katalogu do dzialajacego laboratorium blokad.

---

## Wymagania

Przed startem przygotuj:

- Windows
- .NET SDK 10
- VS Code
- dostep do SQL Server (testowane na SQL Server 2022 DEveleper Edition CU23)
- konto z uprawnieniami do:
  - tworzenia tabeli testowej
  - tworzenia tabeli logow
  - wykonywania `SELECT`, `UPDATE`, `INSERT`
  - odczytu DMV (`sys.dm_exec_requests`, `sys.dm_tran_locks`)

Jesli nie masz uprawnien do odczytu DMV, monitor moze zwracac bledy albo pusty wynik.

---

## Struktura projektu

Docelowa struktura:

```text
SqlLockSimulator
│   SqlLockSimulator.csproj
│   Program.cs
│   appsettings.json
```

---

## Krok 1 - utworzenie projektu

W PowerShell:

```powershell
mkdir C:\temp\SqlLockSimulator
cd C:\temp\SqlLockSimulator

dotnet new console -n SqlLockSimulator
cd .\SqlLockSimulator
```

---

## Krok 2 - dodanie pakietow NuGet

W PowerShell:

```powershell
dotnet add package Microsoft.Data.SqlClient
dotnet add package Microsoft.Extensions.Configuration
dotnet add package Microsoft.Extensions.Configuration.Json
dotnet add package Microsoft.Extensions.Configuration.Binder
```

Te pakiety odpowiadaja za:

- obsluge SQL Server z poziomu C#
- odczyt konfiguracji z `appsettings.json`
- mapowanie konfiguracji do klas

---

## Krok 3 - podmiana plikow projektu

Podmien w projekcie:

- `SqlLockSimulator.csproj`
- `Program.cs`
- `appsettings.json`

Na wersje przygotowane dla narzedzia.

Jeśli chcesz utrzymac kilka konfiguracji, mozesz tez dodac osobne pliki typu:

- `appsettings.Contention.json`
- `appsettings.Deadlock.json`
- `appsettings.Queue.json`

Na poczatek jednak najprosciej zostac przy jednym `appsettings.json`.

---

## Krok 4 - ustawienie connection string

W `appsettings.json` ustaw swoj connection string, np.:

```json
"ConnectionString": "Server=NAZWA_SERWERA;Database=NAZWA_BAZY;Trusted_Connection=True;TrustServerCertificate=True;"
```

### Typowe warianty

#### Windows Authentication

```json
"ConnectionString": "Server=SQL2016DEV;Database=DemoLocks;Trusted_Connection=True;TrustServerCertificate=True;"
```

#### SQL Login

```json
"ConnectionString": "Server=SQL2016DEV;Database=DemoLocks;User Id=demo_user;Password=TwojeHaslo;TrustServerCertificate=True;"
```

### Uwaga

Jesli laczysz sie do instancji nazwanej, np. `MSSQLSERVER2016`, connection string moze wygladac tak:

```json
"ConnectionString": "Server=HOSTNAME\\MSSQLSERVER2016;Database=DemoLocks;Trusted_Connection=True;TrustServerCertificate=True;"
```

---

## Krok 5 - pierwsze uruchomienie

W PowerShell:

```powershell
dotnet restore
dotnet build
dotnet run
```

### Co powinno sie stac

Przy pierwszym uruchomieniu narzedzie moze automatycznie utworzyc:

- tabele testowa `dbo.LockDemo`
- tabele logow `dbo.LockSimulatorRunLog`

O ile masz ustawione:

- `CreateDemoTableIfMissing = true`
- `CreateLogTableIfMissing = true`

Na konsoli zobaczysz m.in.:

- `RunId`
- liczbe workerow
- wybrany scenariusz
- wybrany `TestMode`
- logi workerow i monitorow

---

## Krok 6 - sprawdzenie logow po przebiegu

Po zakonczeniu testu mozesz sprawdzic logi w SQL Server:

```sql
SELECT *
FROM dbo.LockSimulatorRunLog
ORDER BY LogId DESC;
```

Aby odfiltrowac konkretny przebieg, skopiuj `RunId` z konsoli i uzyj:

```sql
DECLARE @RunId UNIQUEIDENTIFIER = 'RUNID';

SELECT
    LogId,
    LoggedAt,
    SourceType,
    SourceName,
    WorkerId,
    IterationNo,
    Spid,
    Severity,
    Message
FROM dbo.LockSimulatorRunLog
WHERE RunId = @RunId
ORDER BY LogId;
```

---

## Jak czytac `RunId`

`RunId` to identyfikator calego przebiegu.

Dzieki niemu:

- wszystkie wpisy workerow sa powiazane z jednym testem
- wszystkie wpisy monitorow sa powiazane z tym samym testem
- mozna porownywac przebiegi miedzy soba

To jest absolutnie kluczowe, bo bez `RunId` szybko zamieniasz diagnostyke w archeologie blota.

---

## Gotowe profile testow

Ponizej masz zestaw gotowych profili, ktore mozesz wklejac do `appsettings.json`.

---

## Profil 1 - Baseline bez hintow

### Cel

Sprawdzic, jak zachowuje sie system bez wymuszonych hintow.

### Konfiguracja

```json
{
  "SqlLockSimulator": {
    "ConnectionString": "Server=YOUR_SQL_SERVER;Database=YOUR_DB;Trusted_Connection=True;TrustServerCertificate=True;",
    "TargetTable": "dbo.LockDemo",
    "WorkerCount": 2,
    "IterationsPerWorker": 1,
    "WorkerTargets": [ 1, 1 ],
    "TestMode": "NoHint",
    "Scenario": "Contention",
    "HoldSeconds": 5,
    "DoUpdate": false,
    "DelayBetweenSelectAndUpdateMs": 0,
    "CommandTimeoutSeconds": 120,
    "CreateDemoTableIfMissing": true,
    "CreateLogTableIfMissing": true,
    "StartDelayMs": 1000,
    "DelayBetweenIterationsMs": 200,
    "EnableDmvMonitor": true,
    "DmvMonitorIntervalMs": 1000,
    "EnableLockMonitor": true,
    "LockMonitorIntervalMs": 1000,
    "EnableSqlLogging": true,
    "RandomizeTargetPerIteration": false,
    "RandomTargetMinId": 1,
    "RandomTargetMaxId": 4
  }
}
```

### Kiedy uzywac

- jako punkt odniesienia
- przed testami z `XLOCK` i `UPDLOCK`
- gdy chcesz sprawdzic, co robi sam domyslny `READ COMMITTED`

---

## Profil 2 - Klasyczny korek na jednym rekordzie (`XLOCK`)

### Cel

Zasymulowac sytuacje, gdzie wiele sesji walczy o jeden rekord i jedna z nich brutalnie blokuje reszte.

### Konfiguracja

```json
{
  "SqlLockSimulator": {
    "ConnectionString": "Server=YOUR_SQL_SERVER;Database=YOUR_DB;Trusted_Connection=True;TrustServerCertificate=True;",
    "TargetTable": "dbo.LockDemo",
    "WorkerCount": 4,
    "IterationsPerWorker": 1,
    "WorkerTargets": [ 1, 1, 1, 1 ],
    "TestMode": "XLock",
    "Scenario": "Contention",
    "HoldSeconds": 15,
    "DoUpdate": false,
    "DelayBetweenSelectAndUpdateMs": 0,
    "CommandTimeoutSeconds": 120,
    "CreateDemoTableIfMissing": true,
    "CreateLogTableIfMissing": true,
    "StartDelayMs": 2000,
    "DelayBetweenIterationsMs": 200,
    "EnableDmvMonitor": true,
    "DmvMonitorIntervalMs": 1000,
    "EnableLockMonitor": true,
    "LockMonitorIntervalMs": 1000,
    "EnableSqlLogging": true,
    "RandomizeTargetPerIteration": false,
    "RandomTargetMinId": 1,
    "RandomTargetMaxId": 4
  }
}
```

### Co zobaczysz

- jeden worker zgarnie `XLOCK`
- pozostali beda czekac
- monitor requestow pokaze `blocking_session_id`
- monitor lockow pokaze ciezsze locki

---

## Profil 3 - Realistyczny flow aplikacyjny (`UPDLOCK` + `UPDATE`)

### Cel

Zasymulowac aplikacje, ktora:

1. czyta rekord
2. rezerwuje go
3. po chwili go aktualizuje

### Konfiguracja

```json
{
  "SqlLockSimulator": {
    "ConnectionString": "Server=YOUR_SQL_SERVER;Database=YOUR_DB;Trusted_Connection=True;TrustServerCertificate=True;",
    "TargetTable": "dbo.LockDemo",
    "WorkerCount": 4,
    "IterationsPerWorker": 2,
    "WorkerTargets": [ 1, 1, 1, 1 ],
    "TestMode": "UpdLock",
    "Scenario": "Contention",
    "HoldSeconds": 10,
    "DoUpdate": true,
    "DelayBetweenSelectAndUpdateMs": 500,
    "CommandTimeoutSeconds": 120,
    "CreateDemoTableIfMissing": true,
    "CreateLogTableIfMissing": true,
    "StartDelayMs": 2000,
    "DelayBetweenIterationsMs": 500,
    "EnableDmvMonitor": true,
    "DmvMonitorIntervalMs": 1000,
    "EnableLockMonitor": true,
    "LockMonitorIntervalMs": 1000,
    "EnableSqlLogging": true,
    "RandomizeTargetPerIteration": false,
    "RandomTargetMinId": 1,
    "RandomTargetMaxId": 4
  }
}
```

### Co zobaczysz

- bardziej naturalny wzorzec pracy aplikacji
- czekanie przy probie wejscia na ten sam rekord
- roznice wzgledem `XLOCK`

---

## Profil 4 - Kolejka robocza (`READPAST`)

### Cel

Sprawdzic, czy workerzy potrafia omijac zablokowane rekordy zamiast stac w kolejce.

### Konfiguracja

```json
{
  "SqlLockSimulator": {
    "ConnectionString": "Server=YOUR_SQL_SERVER;Database=YOUR_DB;Trusted_Connection=True;TrustServerCertificate=True;",
    "TargetTable": "dbo.LockDemo",
    "WorkerCount": 4,
    "IterationsPerWorker": 3,
    "WorkerTargets": [ 1, 2, 3, 4 ],
    "TestMode": "UpdLockReadPast",
    "Scenario": "Queue",
    "HoldSeconds": 5,
    "DoUpdate": true,
    "DelayBetweenSelectAndUpdateMs": 200,
    "CommandTimeoutSeconds": 120,
    "CreateDemoTableIfMissing": true,
    "CreateLogTableIfMissing": true,
    "StartDelayMs": 1000,
    "DelayBetweenIterationsMs": 300,
    "EnableDmvMonitor": true,
    "DmvMonitorIntervalMs": 1000,
    "EnableLockMonitor": true,
    "LockMonitorIntervalMs": 1000,
    "EnableSqlLogging": true,
    "RandomizeTargetPerIteration": false,
    "RandomTargetMinId": 1,
    "RandomTargetMaxId": 4
  }
}
```

### Co zobaczysz

- mniej klasycznego blokowania niz przy biciu w jeden rekord
- lepsza przepustowosc
- sensowny model kolejki roboczej

---

## Profil 5 - Deadlock demo

### Cel

Celowo wywolac deadlock i zobaczyc, jak SQL Server wybiera ofiare.

### Konfiguracja

```json
{
  "SqlLockSimulator": {
    "ConnectionString": "Server=YOUR_SQL_SERVER;Database=YOUR_DB;Trusted_Connection=True;TrustServerCertificate=True;",
    "TargetTable": "dbo.LockDemo",
    "WorkerCount": 4,
    "IterationsPerWorker": 1,
    "WorkerTargets": [ 1, 1, 1, 1 ],
    "TestMode": "UpdLock",
    "Scenario": "Deadlock",
    "HoldSeconds": 3,
    "DoUpdate": true,
    "DelayBetweenSelectAndUpdateMs": 0,
    "CommandTimeoutSeconds": 120,
    "CreateDemoTableIfMissing": true,
    "CreateLogTableIfMissing": true,
    "StartDelayMs": 1000,
    "DelayBetweenIterationsMs": 200,
    "EnableDmvMonitor": true,
    "DmvMonitorIntervalMs": 1000,
    "EnableLockMonitor": true,
    "LockMonitorIntervalMs": 1000,
    "EnableSqlLogging": true,
    "RandomizeTargetPerIteration": false,
    "RandomTargetMinId": 1,
    "RandomTargetMaxId": 4
  }
}
```

### Co zobaczysz

- parzyste i nieparzyste workery beda zamykac rekordy w odwrotnej kolejnosci
- SQL Server powinien ubic jedna transakcje
- w logach pojawi sie blad deadlocka

To jest bardzo dobry profil szkoleniowy i diagnostyczny.

---

## Profil 6 - Ruch losowy jak w produkcji

### Cel

Zblizyc test do bardziej realistycznego rozkladu ruchu.

### Konfiguracja

```json
{
  "SqlLockSimulator": {
    "ConnectionString": "Server=YOUR_SQL_SERVER;Database=YOUR_DB;Trusted_Connection=True;TrustServerCertificate=True;",
    "TargetTable": "dbo.LockDemo",
    "WorkerCount": 4,
    "IterationsPerWorker": 5,
    "WorkerTargets": [ 1, 2, 3, 4 ],
    "TestMode": "UpdLock",
    "Scenario": "Contention",
    "HoldSeconds": 4,
    "DoUpdate": true,
    "DelayBetweenSelectAndUpdateMs": 200,
    "CommandTimeoutSeconds": 120,
    "CreateDemoTableIfMissing": true,
    "CreateLogTableIfMissing": true,
    "StartDelayMs": 1000,
    "DelayBetweenIterationsMs": 300,
    "EnableDmvMonitor": true,
    "DmvMonitorIntervalMs": 1000,
    "EnableLockMonitor": true,
    "LockMonitorIntervalMs": 1000,
    "EnableSqlLogging": true,
    "RandomizeTargetPerIteration": true,
    "RandomTargetMinId": 1,
    "RandomTargetMaxId": 4
  }
}
```

### Co zobaczysz

- bardziej zmienny rozklad blokad
- niektore rekordy beda gorace czesciej niz inne
- dobry material do obserwacji jak zachowuje sie baza przy mniej przewidywalnym ruchu

---

## Jak przechodzic przez profile testowe

Najlepsza kolejnosc pracy:

1. **Baseline (`NoHint`)**
2. **XLock**
3. **UpdLock**
4. **UpdLockReadPast**
5. **Deadlock**
6. **Random traffic**

To pozwala porownywac scenariusze krok po kroku, zamiast wrzucac sie od razu w pieklo i udawac, ze to metodologia.

---

## Jak uruchamiac kolejne testy

### Wariant prosty

1. Podmien konfiguracje w `appsettings.json`
2. Zapisz plik
3. Uruchom:

```powershell
dotnet run
```

### Wariant bezpieczniejszy

Przed kazdym testem:

- wyczysc albo zachowaj `RunId`
- zanotuj profil
- uruchom tylko jeden przebieg naraz
- po tescie sprawdz logi

---

## Jak szybko analizowac wynik po tescie

### Wszystkie wpisy dla danego przebiegu

```sql
DECLARE @RunId UNIQUEIDENTIFIER = 'RUNID';

SELECT
    LogId,
    LoggedAt,
    SourceType,
    SourceName,
    WorkerId,
    IterationNo,
    Spid,
    Severity,
    Message
FROM dbo.LockSimulatorRunLog
WHERE RunId = @RunId
ORDER BY LogId;
```

### Tylko bledy i ostrzezenia

```sql
DECLARE @RunId UNIQUEIDENTIFIER = 'RUNID';

SELECT
    LoggedAt,
    SourceName,
    Severity,
    Message
FROM dbo.LockSimulatorRunLog
WHERE RunId = @RunId
  AND Severity IN ('WARN', 'ERROR')
ORDER BY LogId;
```

### Tylko monitor requestow

```sql
DECLARE @RunId UNIQUEIDENTIFIER = '_RUNID';

SELECT
    LoggedAt,
    Message
FROM dbo.LockSimulatorRunLog
WHERE RunId = @RunId
  AND SourceType = 'MONITOR'
  AND SourceName IN ('REQ', 'REQ_ERR')
ORDER BY LogId;
```

### Tylko monitor lockow

```sql
DECLARE @RunId UNIQUEIDENTIFIER = 'RUNID';

SELECT
    LoggedAt,
    Message
FROM dbo.LockSimulatorRunLog
WHERE RunId = @RunId
  AND SourceType = 'MONITOR'
  AND SourceName IN ('LOCK', 'LOCK_ERR')
ORDER BY LogId;
```

---

## Najczestsze problemy przy uruchamianiu

### 1. Brak dostepu do DMV

Objaw:

- monitor zwraca bledy
- brak danych z requestow lub lockow

Przyczyna:

- konto nie ma odpowiednich uprawnien do DMV

Rozwiazanie:

- uruchom test kontem z odpowiednimi uprawnieniami
- albo tymczasowo wylacz monitory

---

### 2. Tabela logow nie tworzy sie

Objaw:

- blad przy starcie

Przyczyna:

- brak uprawnien do `CREATE TABLE`

Rozwiazanie:

- utworz tabele recznie
- albo uruchom test kontem z wyzszymi uprawnieniami

---

### 3. Deadlock nie wystepuje

Objaw:

- test deadlock dziala, ale nikt nie staje sie ofiara

Przyczyna:

- zbyt male nakladanie czasowe sesji
- za mala liczba workerow
- za krotki `HoldSeconds`

Rozwiazanie:

- zwieksz `HoldSeconds`
- ustaw `StartDelayMs` nisko
- zostaw 4 workery

---

### 4. Ruch jest zbyt chaotyczny do analizy

Objaw:

- log jest trudny do zrozumienia

Przyczyna:

- za duzo workerow
- za duzo iteracji
- losowe targety

Rozwiazanie:

- zacznij od:
  - 2 workerow
  - 1 iteracji
  - jednego rekordu

---

## Rekomendowany plan warsztatowy

### Etap 1
Uruchom baseline i sprawdz, jak wyglada zachowanie bez hintow.

### Etap 2
Uruchom `XLock` i zobacz roznice.

### Etap 3
Uruchom `UpdLock` z `DoUpdate = true`.

### Etap 4
Uruchom profil kolejki z `READPAST`.

### Etap 5
Uruchom deadlock demo.

### Etap 6
Uruchom ruch losowy i porownaj z profilem statycznym.

To daje ci pelny przekroj od prostych blokad do realistyczniejszego chaosu.

---

## Podsumowanie

Dzieki tym profilom mozesz bardzo szybko:

- uruchomic narzedzie w VS Code
- odwzorowac scenariusze z pracy
- porownac zachowanie roznych hintow
- sprawdzic blokowanie, wait i deadlocki
- analizowac wyniki po `RunId`


