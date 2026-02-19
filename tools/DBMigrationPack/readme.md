# SQL Migration Toolkit (PowerShell) — precheck → backup/restore → postcheck

Zestaw skryptów do bezpiecznej migracji baz SQL Server w modelu:  
**PRECHECK (source) → READ_ONLY (source) → BACKUP/RESTORE → POSTCHECK (destination)**  
Dodatkowo (opcjonalnie): **zaplanowanie usunięcia baz na source po 7 dniach**.

> Założenie operacyjne: po cutover baza na **source** zostaje w `READ_ONLY` jako „bezpiecznik”, a po 7 dniach jest usuwana.

---

## Wymagania

- Windows + PowerShell 5.1+ (lub 7.x)
- Dostęp sieciowy do `source`, `destination` i udziału `backuppath` (UNC)
- Uprawnienia:
  - na **source**: możliwość odczytu metadanych i zmiany stanu baz (ALTER DATABASE)
  - na **destination**: możliwość odtwarzania baz i zmiany ustawień (ALTER DATABASE)
- Moduł PowerShell: **SqlServer** (dla `Invoke-Sqlcmd`)

Instalacja modułu (jeśli trzeba):
```powershell
Install-Module SqlServer -Scope CurrentUser
```

---

## Struktura plików

Przykładowy układ katalogu:

```
.
├─ config.json
├─ precheck-migration.ps1
├─ Invoke-SqlBackupRestore.ps1
├─ postcheck-migration.ps1
├─ run-migration.ps1
├─ schedule-drop-after-7days.ps1   (opcjonalnie)
└─ logs\
```

---

## Konfiguracja (config.json)

Przykład:

```json
{
  "source": "SQL31.domena.pl,1520",
  "destination": "SQL32.domena.pl,1530",
  "backuppath": "\\\\filesrv01\\sqlbackups\\migracje",
  "databases": ["AdventureWorks2022", "ERPCS_PROD"],

  "sourceCredential": { "type": "windows" },
  "destinationCredential": { "type": "windows" },

  "backupOptions": {
    "copyOnly": true,
    "compress": true,
    "checksum": true,
    "init": true,
    "stats": 10
  },

  "restoreOptions": {
    "replace": true,
    "recover": true,
    "moveFiles": true,
    "dataDir": "D:\\SQLData",
    "logDir": "E:\\SQLLog"
  },

  "logOptions": {
    "logDir": "C:\\Scripts\\logs",
    "alsoWriteToConsole": true
  },

  "throttleLimit": 3
}
```

---

## Jak działa pipeline

### 1) `precheck-migration.ps1` (SOURCE)
- waliduje każdą bazę z listy:
  - czy istnieje,
  - czy jest `ONLINE`,
  - ile jest aktywnych sesji,
  - podstawowe flagi bezpieczeństwa operacyjnego
- następnie przełącza bazę na **`READ_ONLY WITH ROLLBACK IMMEDIATE`**  
  (odcina aktywne połączenia, żeby zmiana była deterministyczna)

Uruchomienie:
```powershell
.\precheck-migration.ps1 -ConfigPath .\config.json
```

### 2) `Invoke-SqlBackupRestore.ps1` (BACKUP/RESTORE)
- wykonuje backup na `backuppath`
- odtwarza na `destination` (z opcjami `MOVE`, `REPLACE`, itd. wg configa)
- loguje przebieg

Uruchomienie:
```powershell
.\Invoke-SqlBackupRestore.ps1 -ConfigPath .\config.json
```

### 3) `postcheck-migration.ps1` (DESTINATION)
Po restore ustawia na **destination**:
- baza: `READ_WRITE`
- `COMPATIBILITY_LEVEL = 160` (SQL Server 2022)
- `QUERY_STORE = ON`, `OPERATION_MODE = READ_WRITE`
- `MAX_STORAGE_SIZE_MB = 2048` (2GB)
- loguje weryfikację (stan Query Store + ustawienia)

Uruchomienie:
```powershell
.\postcheck-migration.ps1 -ConfigPath .\config.json
```

---

## Orchestrator (jedno uruchomienie)

`run-migration.ps1` odpala kroki w kolejności:
1) precheck
2) backup/restore
3) postcheck
4) opcjonalnie schedule drop

Uruchomienie:
```powershell
.\run-migration.ps1 `
  -ConfigPath .\config.json `
  -PrecheckScriptPath .\precheck-migration.ps1 `
  -BackupRestoreScriptPath .\Invoke-SqlBackupRestore.ps1 `
  -PostcheckScriptPath .\postcheck-migration.ps1
```

Z automatycznym DROP po 7 dniach:
```powershell
.\run-migration.ps1 `
  -ConfigPath .\config.json `
  -PrecheckScriptPath .\precheck-migration.ps1 `
  -BackupRestoreScriptPath .\Invoke-SqlBackupRestore.ps1 `
  -PostcheckScriptPath .\postcheck-migration.ps1 `
  -ScheduleDropAfterDays 7 `
  -ScheduleDropScriptPath .\schedule-drop-after-7days.ps1
```

---

## (Opcjonalnie) Automatyczny DROP baz na source po 7 dniach

Jeśli w Twoim procesie baza na **source** ma zostać usunięta po 7 dniach,
możesz zaplanować SQL Agent Job dla każdej bazy:

```powershell
.\schedule-drop-after-7days.ps1 -ConfigPath .\config.json -Days 7
```

Job ma zabezpieczenie: wykona `DROP` tylko jeśli baza nadal jest `READ_ONLY` i `ONLINE`.

---

## Logi i diagnostyka

Wszystkie skrypty zapisują logi do katalogu:
`logOptions.logDir`

W logach szukaj:
- `PRECHECK FAIL` / `POSTCHECK FAIL`
- szczegółów `QueryStore | actual/desired/readonly_reason`
- nazw utworzonych backupów / ścieżek `MOVE`

---

## Najczęstsze problemy

### 1) Brak modułu SqlServer
Rozwiązanie:
```powershell
Install-Module SqlServer -Scope CurrentUser
```

### 2) Brak dostępu do `backuppath`
Pamiętaj: dostęp do udziału musi mieć **konto usługi SQL Server** (nie tylko Twoja sesja).  
Jeśli backup robisz z T-SQL po stronie serwera, to serwer „czyta” UNC w kontekście usługi.

### 3) Query Store nie wchodzi w READ_WRITE
W logu zobaczysz `readonly_reason`. Najczęściej:
- baza jest `READ_ONLY`,
- problem z miejscem / IO,
- ustawienia/stan bazy po restore.

Postcheck robi jawnie `READ_WRITE` przed ustawieniami QS.

---

## Bezpieczny cutover (praktyka)

- Source zostaje `READ_ONLY` (blokada split-brain).
- Po przełączeniu aplikacji/połączeń na destination, obserwujesz 7 dni.
- Po 7 dniach (jeśli brak rollback) — DROP na source.

---
