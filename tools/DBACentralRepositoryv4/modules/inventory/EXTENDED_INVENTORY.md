# Inventory v4 — Etap 2: obiekty, HA i wykrywanie zmian

## Instalacja

Na istniejącym LAB wystarczy wykonać:

```powershell
git pull --ff-only
cd tools/DBACentralRepositoryv4
./docker/Initialize-Repository.ps1
./docker/Test-Inventory.ps1
./docker/Test-Inventory.ps1 -Persist
./docker/Test-Inventory-Changes.ps1
```

Instalator wykona `sql/04_Extended_Inventory_And_Diff.sql` po poprzednich czterech skryptach. Nie nadpisuje danych istniejących snapshotów.

## Zakres kolekcji

- **DB**: obiekty użytkownika (tabele/widoki/procedury/funkcje/triggery), schematy, kolumny, FK, indeksy i ich kolumny, partycje, statystyki i ich kolumny, funkcje/schematy partycjonowania.
- **Instance**: ustawienia `sys.configurations`, tempdb, linked servers (bez provider string), metadane credentials (bez sekretów), trace flags, usługi, wolumeny.
- **HA**: FCI — węzły i właściciel z `sys.dm_os_cluster_nodes` (tylko jeśli IsClustered=1); nazwa SQL VNN nie jest nazwą fizycznego klastra WSFC; AG — repliki i bazy z DMV (tylko jeśli IsHadrEnabled=1).
- **Security**: istniejące odczyty ról i uprawnień serwerowych/bazodanowych.

Kolektor **nie wykonuje** TABLE SCAN, `FULLSCAN`, `UPDATE STATISTICS`, `DBCC CHECKDB` ani restartów/failoverów. Odczytuje metadane katalogowe; `sys.partitions.rows` to oszacowanie liczby wierszy, nie pomiar `COUNT(*)`.

## Wykrywanie zmian

`inventory.ScanCategory` rejestruje także kategorie z zerową liczbą obiektów i status ich kompletności. Procedura `inventory.usp_CompareCompletedScans` porównuje tylko dwa pełne skany tej samej instancji, i tylko kategorie poprawnie zakończone w obu przebiegach.

Zmiany zapisuje `inventory.ChangeEvent`:
- ADDED — nowy obiekt / wpis katalogowy,
- REMOVED — usunięty,
- MODIFIED — zmienione metadane.

Dane historyczne z poprzedniej wersji kolektora nie mają `ScanCategory`, dlatego pierwszy skan po aktualizacji staje się nowym punktem odniesienia. Dopiero następny skan generuje miarodajne zdarzenia.

```sql
SELECT TOP(100) *
FROM report.vInventoryChanges
ORDER BY DetectedUtc DESC,ChangeEventId DESC;

SELECT TOP(10) * FROM inventory.ScanRun ORDER BY ScanRunId DESC;
SELECT * FROM inventory.ScanCategory WHERE ScanRunId=(SELECT MAX(ScanRunId) FROM inventory.ScanRun);
```

## Uprawnienia i bezpieczeństwo

Do części DMV wymagane są uprawnienia VIEW SERVER STATE / VIEW SERVER PERFORMANCE STATE (zależnie od wersji) i prawa w bazach. Gdy kategoria się nie powiedzie, ScanRun otrzymuje PARTIAL, a `ScanFinding` rejestruje błąd. Na produkcji nie używać SA.

Zmiany SQL Agent, metadane logowania i role to informacje wrażliwe. Repozytorium należy zabezpieczyć osobną rolą tylko do odczytu raportów, odrębnym kontem zapisu i kontrolą retencji.

## Ograniczenia / kolejne prace

1. Brak testów na FCI/AG w Docker standalone — to ścieżka do testów na Windows LAB.
2. Snapshoty zapisujemy paczkami SqlBulkCopy (500 wierszy); potrzebujemy jeszcze pomiarów wydajności i retencji dla bardzo dużych instancji.
3. Historia zdarzeń to porównanie dwóch kolejnych kompletnych skanów; nie jest to audyt DDL w czasie rzeczywistym.
4. Klucze obiektów oparte o object_id mogą nie wykryć zmiany nazwy jako RENAME; zalecany jest dodatkowy raport nazw.
5. Zbierane metadane zależą od widoczności katalogów dla użytkownika kolektora.

## VOLUME: pomiary vs. zmiany konfiguracji

Kolektor nadal zapisuje `available_bytes` w `inventory.InventorySnapshot.DataJson`. Procedura porównania pomija **tylko** `available_bytes` w kategorii VOLUME przy sprawdzaniu `MODIFIED`, ponieważ jest to chwilowy pomiar wolnego miejsca. Inne atrybuty, np. `total_bytes`, `file_system_type` i identyfikator wolumenu, pozostają porównywane. Oryginalne JSON w ChangeEvent nie są modyfikowane.

Poprzednie zdarzenia ChangeEvent pozostają zapisane; aktualizacja procedury nie usuwa istniejącej historii. Przed uznaniem tych wcześniejszych zmian za fałszywe alarmy można porównać pola JSON z obu snapshotów:

```sql
SELECT ScanRunId, EntityKey,
       JSON_VALUE(OldJson,'$.available_bytes') AS OldAvailableBytes,
       JSON_VALUE(NewJson,'$.available_bytes') AS NewAvailableBytes,
       JSON_VALUE(OldJson,'$.total_bytes') AS OldTotalBytes,
       JSON_VALUE(NewJson,'$.total_bytes') AS NewTotalBytes
FROM inventory.ChangeEvent
WHERE Category='VOLUME' AND ScanRunId IN (3,4)
ORDER BY ScanRunId,EntityKey;
```

## Walidacja MODIFIED / REMOVED w Docker LAB

Uruchom z katalogu `tools/DBACentralRepositoryv4`:

```powershell
./docker/Test-Inventory-ModifiedRemoved.ps1
```

Skrypt **nie modyfikuje istniejącej tabeli testowej**. Tworzy nową tabelę `tempdb.dbo.InventoryV4Probe_*`, wykonuje skan bazowy, zmienia kolumnę `Note` z `nvarchar(50)` na `nvarchar(100)`, weryfikuje `COLUMN/MODIFIED`, usuwa własną tabelę i weryfikuje `OBJECT/REMOVED` oraz dwa `COLUMN/REMOVED`. Na końcu usuwa tabelę testową również w razie wyjątku. Jest ograniczony do `127.0.0.1:15433/15434`, środowiska `LAB` i instancji o nazwie `sqlmaniak-v4-target`. Wynik końcowy: `PASS: MODIFIED + REMOVED verified`.

Historyczne pomiary `VOLUME` ze skanów 3 i 4 różniły się wartością `available_bytes`, bez zmian `total_bytes`; po poprawce skan 6 zgłosił `changes=0` względem skanu 5.
