# Inventory collector — PowerShell 7 (etap 1)

## Wymagania

- PowerShell 7.
- SQL Server 2016 lub nowszy oraz dostępna biblioteka `System.Data.SqlClient` (testować zgodność na docelowej stacji).
- Dostęp do źródeł pozwalający odczytać potrzebne widoki katalogowe i metadane SQL Agent.
- Dla zapisu do centralnego repozytorium: prawa INSERT do `inventory.InventorySnapshot`, `inventory.ScanRun`, `inventory.ScanFinding`, prawo SELECT oraz prawo INSERT do `inventory.Instance` i UPDATE do `inventory.ScanRun`; instalacja schematu wymaga osobnych uprawnień.
- Nie używać kont SQL i haseł w JSON. Domyślnie Integrated Security; opcjonalnie `Get-Credential`.

## Przygotowanie bazy LAB

Uruchom w SSMS skrypty z `sql/` w kolejności: `00_Bootstrap.sql`, `01_Inventory_Core.sql`, `02_Patch_Planner.sql`, `03_Reports.sql`.

Zapisz kopię `config/servers.example.json` jako `config/servers.local.json` i wpisz rzeczywiste adresy LAB (nigdy haseł). Nie commituj pliku z parametrami środowiska.

## Uruchomienie

Z katalogu `tools/DBACentralRepositoryv4`:

```powershell
# Inspekcja źródła — bez zapisywania do centralnego repozytorium
pwsh ./modules/inventory/Collect-DBAInventory.ps1 -ConfigPath ./config/servers.local.json

# Po walidacji skryptów na LAB: zapis do bazy v4
pwsh ./modules/inventory/Collect-DBAInventory.ps1 -ConfigPath ./config/servers.local.json -Persist
```

W środowisku Windows z uwierzytelnianiem SQL (bez sekretów w plikach):

```powershell
$sourceCredential = Get-Credential
$repoCredential = Get-Credential
./modules/inventory/Collect-DBAInventory.ps1 -ConfigPath ./config/servers.local.json `
  -SourceCredential $sourceCredential -RepositoryCredential $repoCredential
```

## Co jest gotowe, a co nie

Obecnie: kolektor podstawowych kategorii inwentaryzacyjnych z obsługą częściowych błędów, podstawowa baza i historia snapshotów.

Nie gotowe: skan całych obiektów/indeksów/statystyk, FCI/AG, differential inventory, walidacja kompletności uprawnień, integracja DHC, patch execution i testy end-to-end. Plik nie został jeszcze zweryfikowany na działającym SQL Server z PowerShell 7. **Przed zapisem na produkcji obowiązują testy LAB.**

Dane konfiguracyjne i opis role membership są metadanymi wrażliwymi; repozytorium powinno być odpowiednio chronione. Dane o uprawnieniach mogą być niekompletne, gdy konto kolektora nie ma wystarczających praw.
