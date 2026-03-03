# SQL Lock Simulator  - opis mozliwosci i scenariusze testowe

## Cel narzedzia

SQL Lock Simulator V3 to konsolowe narzedzie w C# do symulowania wspolbieznosci na jednej bazie SQL Server.

Pozwala odwzorowac sytuacje zblizone do srodowiska produkcyjnego, gdzie wiele serwerow aplikacyjnych lub wiele instancji aplikacji jednoczesnie wykonuje operacje na tych samych danych.

Narzedzie zostalo zaprojektowane do analizy:

- blokad (locks)
- oczekiwan (waits)
- blokowania sesji (blocking)
- konfliktow wspolbieznosci
- deadlockow
- zachowania hintow (XLOCK, UPDLOCK, READPAST, HOLDLOCK)
- wplywu roznych wzorcow odczytu i zapisu na prace SQL Server

---

## Co potrafi narzedzie

### 1. Uruchamia wielu workerow rownolegle

Kazdy worker:

- otwiera osobne polaczenie do SQL Server
- dostaje wlasny SPID
- dziala jak niezalezny serwer aplikacyjny

Dzieki temu mozna zasymulowac np. 4 serwery aplikacyjne uderzajace do jednej bazy.

---

### 2. Wykonuje wiele iteracji

Kazdy worker moze wykonac wiele rund testowych.

Przydaje sie to do:

- powtarzalnych testow
- symulacji stalego ruchu
- analizy zachowania bazy pod dluzszym obciazeniem

Konfiguruje to parametr:

- `IterationsPerWorker`

---

### 3. Obsluguje rozne tryby blokowania (`TestMode`)

Dostepne tryby:

- `XLock`
- `UpdLock`
- `UpdLockReadPast`
- `UpdLockHoldLock`
- `NoHint`

### Mapowanie trybow

- `XLock` -> `WITH (XLOCK, ROWLOCK)`
- `UpdLock` -> `WITH (UPDLOCK, ROWLOCK)`
- `UpdLockReadPast` -> `WITH (UPDLOCK, READPAST, ROWLOCK)`
- `UpdLockHoldLock` -> `WITH (UPDLOCK, HOLDLOCK, ROWLOCK)`
- `NoHint` -> bez hintow

---

### 4. Obsluguje rozne scenariusze (`Scenario`)

Dostepne scenariusze:

- `Contention`
- `Queue`
- `Deadlock`

#### `Contention`
Klasyczny scenariusz walki o ten sam rekord lub o ten sam zestaw rekordow.

Przydatny do analizy:

- kto blokuje
- kto czeka
- jak dlugo trwa oczekiwanie
- jak zachowuja sie rozne hinty

#### `Queue`
Scenariusz kolejki roboczej.

Najczesciej uzywany z:

- `UpdLockReadPast`

Pozwala zasymulowac sytuacje, gdzie workerzy pobieraja kolejne rekordy do przetworzenia i omijaja te juz zablokowane.

#### `Deadlock`
Scenariusz celowo budujacy deadlock.

Przyklad:

- worker 1 blokuje rekord 1, potem chce rekord 2
- worker 2 blokuje rekord 2, potem chce rekord 1

To bardzo dobry test do nauki i diagnostyki konfliktow blokad.

---

### 5. Moze wykonywac `UPDATE`

Narzedzie moze dzialac w dwoch stylach:

- tylko `SELECT` z hintem
- `SELECT` + pozniejszy `UPDATE`

To pozwala odwzorowac realny wzorzec aplikacyjny:

1. odczytaj rekord
2. zarezerwuj go
3. przetworz
4. zaktualizuj

Parametr:

- `DoUpdate`

---

### 6. Moze losowac rekordy

Narzedzie moze przy kazdej iteracji losowac rekord z okreslonego zakresu.

To daje bardziej realistyczny model ruchu, zblizony do produkcji.

Parametry:

- `RandomizeTargetPerIteration`
- `RandomTargetMinId`
- `RandomTargetMaxId`

---

### 7. Monitoruje aktywne requesty

Monitor requestow odczytuje dane z:

- `sys.dm_exec_requests`

Loguje m.in.:

- `session_id`
- `blocking_session_id`
- `status`
- `command`
- `wait_type`
- `wait_time`
- `last_wait_type`
- `database_name`
- fragment SQL

To pozwala zobaczyc, ktore sesje:

- wykonuja zapytanie
- czekaja
- blokuja inne

---

### 8. Monitoruje locki

Monitor lockow odczytuje dane z:

- `sys.dm_tran_locks`

Loguje m.in.:

- `request_session_id`
- `resource_type`
- `request_mode`
- `request_status`
- `resource_description`

To pozwala zobaczyc:

- jakie locki trzymaja workery
- na jakim zasobie
- w jakim trybie (`S`, `U`, `X`, itd.)

---

### 9. Loguje przebieg do SQL Server

Narzedzie zapisuje zdarzenia do tabeli:

- `dbo.LockSimulatorRunLog`

Logowane sa m.in.:

- `RunId`
- czas zdarzenia
- worker
- iteracja
- `SPID`
- poziom (`INFO`, `WARN`, `ERROR`)
- opis zdarzenia

To pozwala analizowac test po zakonczeniu, a nie tylko patrzec na konsole.

---

## Najwazniejsze elementy konfiguracji

Przykladowa sekcja:

```json
{
  "SqlLockSimulator": {
    "ConnectionString": "Server=YOUR_SQL_SERVER;Database=YOUR_DB;Trusted_Connection=True;TrustServerCertificate=True;",
    "TargetTable": "dbo.LockDemo",
    "WorkerCount": 4,
    "IterationsPerWorker": 3,
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
    "DelayBetweenIterationsMs": 500,
    "EnableDmvMonitor": true,
    "DmvMonitorIntervalMs": 2000,
    "EnableLockMonitor": true,
    "LockMonitorIntervalMs": 2000,
    "EnableSqlLogging": true,
    "RandomizeTargetPerIteration": false,
    "RandomTargetMinId": 1,
    "RandomTargetMaxId": 4
  }
}
```

---

## Opis parametrow

### `ConnectionString`
Polaczenie do SQL Server.

### `TargetTable`
Tabela testowa, na ktorej wykonywane sa operacje.

### `WorkerCount`
Liczba rownoleglych workerow.

### `IterationsPerWorker`
Liczba iteracji wykonywanych przez kazdego workera.

### `WorkerTargets`
Lista `Id`, ktore beda przypisane workerom.
Jesli kazdy worker ma ten sam `Id`, rosnie szansa na blokowanie.

### `TestMode`
Tryb hintow SQL.

### `Scenario`
Scenariusz testowy (`Contention`, `Queue`, `Deadlock`).

### `HoldSeconds`
Ile sekund worker trzyma transakcje po `SELECT`.

### `DoUpdate`
Czy po `SELECT` ma zostac wykonany `UPDATE`.

### `DelayBetweenSelectAndUpdateMs`
Opoznienie pomiedzy `SELECT` i `UPDATE`.

### `CommandTimeoutSeconds`
Timeout polecen SQL.

### `CreateDemoTableIfMissing`
Czy automatycznie utworzyc tabele demo, jesli nie istnieje.

### `CreateLogTableIfMissing`
Czy automatycznie utworzyc tabele logow.

### `StartDelayMs`
Opoznienie przed wspolnym startem workerow.

### `DelayBetweenIterationsMs`
Przerwa miedzy iteracjami workera.

### `EnableDmvMonitor`
Czy wlaczyc monitor requestow.

### `DmvMonitorIntervalMs`
Co ile milisekund odczytywac `sys.dm_exec_requests`.

### `EnableLockMonitor`
Czy wlaczyc monitor lockow.

### `LockMonitorIntervalMs`
Co ile milisekund odczytywac `sys.dm_tran_locks`.

### `EnableSqlLogging`
Czy zapisywac logi do tabeli SQL.

### `RandomizeTargetPerIteration`
Czy losowac rekord w kazdej iteracji.

### `RandomTargetMinId`, `RandomTargetMaxId`
Zakres losowanych `Id`.

---

## Jak tworzyc testy

Najwazniejsza zasada: test powinien odpowiadac na konkretne pytanie diagnostyczne.


---

## Typy testow i ich cel

### Test 1 - klasyczne blokowanie jednego rekordu

**Cel:** sprawdzic, jak zachowuje sie kilka sesji walczacych o ten sam rekord.

Konfiguracja:

```json
"Scenario": "Contention",
"TestMode": "XLock",
"WorkerTargets": [ 1, 1, 1, 1 ],
"HoldSeconds": 15,
"DoUpdate": false
```

Co obserwowac:

- ktory `SPID` blokuje
- ile czekaja pozostali
- jaki jest `wait_type`
- jak dlugo trzymany jest `XLOCK`

To bardzo dobry test do symulacji "wszyscy bija w ten sam rekord".

---

### Test 2 - odczyt + pozniejsza aktualizacja

**Cel:** odwzorowac realny flow aplikacyjny.

Konfiguracja:

```json
"Scenario": "Contention",
"TestMode": "UpdLock",
"WorkerTargets": [ 1, 1, 1, 1 ],
"HoldSeconds": 10,
"DoUpdate": true
```

Co obserwowac:

- czy `UPDLOCK` ogranicza wyscig
- jak wygladaja waity przy `UPDATE`
- czy ruch jest plynniejszy niz przy `XLOCK`

To zwykle lepiej odwzorowuje aplikacje niz sam `XLOCK`.

---

### Test 3 - kolejka robocza

**Cel:** sprawdzic scenariusz pobierania prac z kolejki.

Konfiguracja:

```json
"Scenario": "Queue",
"TestMode": "UpdLockReadPast",
"WorkerTargets": [ 1, 2, 3, 4 ],
"HoldSeconds": 5,
"DoUpdate": true
```

Co obserwowac:

- czy workerzy omijaja zablokowane rekordy
- czy spada liczba oczekiwan
- czy zwieksza sie przepustowosc

To bardzo dobry model dla systemow typu "wez nastepny task".

---

### Test 4 - deadlock

**Cel:** celowo wywolac deadlock i zobaczyc jego objawy.

Konfiguracja:

```json
"Scenario": "Deadlock",
"TestMode": "UpdLock",
"HoldSeconds": 3,
"DoUpdate": true
```

Co obserwowac:

- ktory worker staje sie ofiara deadlocka
- jak wyglada log bledow
- jak SQL Server przerywa jedna z transakcji

To swietny test do nauki i do przygotowania sie na prawdziwe deadlocki w produkcji.

---

### Test 5 - ruch losowy

**Cel:** zblizyc test do prawdziwego ruchu produkcyjnego.

Konfiguracja:

```json
"Scenario": "Contention",
"TestMode": "UpdLock",
"RandomizeTargetPerIteration": true,
"RandomTargetMinId": 1,
"RandomTargetMaxId": 4,
"DoUpdate": true
```

Co obserwowac:

- jak rozklada sie ruch
- ktore rekordy sa czesciej blokowane
- czy problem dotyczy calej tabeli, czy tylko goracych rekordow

To dobry test do symulacji nierownomiernego ruchu.

---

## Jak projektowac dobry test

### 1. Okresl pytanie
Przyklady:

- Czy `XLOCK` powoduje dlugie blokowanie?
- Czy `UPDLOCK` pomaga ograniczyc race condition?
- Czy `READPAST` zmniejsza kolejki?
- Czy moj wzorzec odczyt + update moze generowac deadlock?

Bez pytania test jest tylko halasem.

---

### 2. Zmieniaj jeden parametr naraz
Najlepiej porownywac:

- ten sam scenariusz
- ta sama liczba workerow
- ten sam `HoldSeconds`

i zmieniac tylko:

- `TestMode`
- albo `DoUpdate`
- albo `WorkerTargets`

Inaczej trudno ocenic, co naprawde mialo wplyw.

---

### 3. Zaczynaj od prostych testow
Najpierw:

- 2 workery
- 1 iteracja
- 1 rekord

Dopiero potem:

- 4 workery
- wiele iteracji
- losowe rekordy
- deadlocki

Inaczej bardzo latwo narobic sobie chaosu bez zrozumienia przyczyny.

---

### 4. Patrz rownoczesnie na 3 rzeczy

Podczas testu analizuj:

- log konsoli
- monitor requestow
- monitor lockow

A po tescie:

- `dbo.LockSimulatorRunLog`

Dopiero polaczenie tych danych daje pelny obraz.

---

### 5. Notuj `RunId`
Kazdy przebieg ma wlasny `RunId`.

To pozwala pozniej latwo odfiltrowac tylko jeden test:

```sql
DECLARE @RunId UNIQUEIDENTIFIER = 'TU_WKLEJ_RUNID';

SELECT *
FROM dbo.LockSimulatorRunLog
WHERE RunId = @RunId
ORDER BY LogId;
```



---

## Jak analizowac wyniki

### Szukaj blokowania
W logach monitorow patrz na:

- `blocking_session_id`
- `wait_type`
- `wait_time`

Jesli wiele sesji pokazuje ten sam `blocking_session_id`, to znalazles winowajce.

---

### Szukaj dlugich transakcji
Jesli worker dlugo trzyma:

- `BEGIN TRAN`
- `SELECT`
- `HOLD`
- `COMMIT`

to wlasnie dlugosc transakcji moze byc glownym zrodlem problemu.

---

### Szukaj lockow agresywnych
Przy `XLOCK` lub `HOLDLOCK` zobaczysz zwykle ciezsze blokowanie niz przy `UPDLOCK`.

To pozwala porownywac wplyw hintow.

---

### Szukaj wzorcow deadlock
Jesli w logach pojawia sie blad deadlocka, porownaj:

- kolejnosc dostepu do rekordow
- workerow parzystych i nieparzystych
- moment zalozenia pierwszego i drugiego locka

To pomaga znalezc zly porzadek operacji.

---

## Przykladowy plan testow diagnostycznych

### Etap 1 - baseline
- `Scenario = Contention`
- `TestMode = NoHint`
- 2 workery
- 1 iteracja

Sprawdzasz zachowanie bez hintow.

### Etap 2 - agresywny lock
- `TestMode = XLock`

Porownujesz do baseline.

### Etap 3 - wersja aplikacyjna
- `TestMode = UpdLock`
- `DoUpdate = true`

Sprawdzasz, czy to lepiej oddaje produkcje.

### Etap 4 - kolejka
- `TestMode = UpdLockReadPast`

Sprawdzasz, czy workerzy przestaja stac w korku.

### Etap 5 - deadlock
- `Scenario = Deadlock`

Sprawdzasz, czy obecny wzorzec dostepu moze tworzyc cykl blokad.

---

## Dobre praktyki

- testuj najpierw na srodowisku labowym
- zaczynaj od malych wartosci
- nie uzywaj od razu duzej liczby workerow
- nie mieszaj wielu scenariuszy naraz
- zapisuj `RunId`
- porownuj testy parami
- patrz na efekt hintow, nie tylko na sam czas wykonania

---

## Czego to narzedzie nie zastepuje

To narzedzie jest swietne do symulacji wspolbieznosci, ale nie zastepuje:

- analizy planow wykonania
- analizy statystyk
- analizy indeksow
- Extended Events
- Query Store
- monitoringu produkcyjnego

To jest **symulator i laboratorium**

---

## Pomysly na dalsza rozbudowe

Mozliwe rozszerzenia:

- eksport do CSV / JSON
- osobna tabela naglowkow przebiegow (`RunHeader`)
- zapis czasu wykonania do osobnych kolumn
- monitor `sys.dm_os_waiting_tasks`
- obsluga roznych connection stringow per worker
- scenariusze burst traffic
- symulacja retry i timeoutow aplikacyjnych

---

## Podsumowanie

SQL Lock Simulator  pozwala:

- zasymulowac wiele aplikacji uderzajacych do jednej bazy
- odtwarzac blokady, waity i deadlocki
- testowac wplyw hintow
- porownywac rozne wzorce dostepu do danych
- logowac przebiegi do SQL Server
- analizowac test po fakcie
