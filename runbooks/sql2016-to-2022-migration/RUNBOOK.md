# SQL Server 2016 to 2022 Migration — RUNBOOK

## 1. Day -7..-1 przygotowanie

Wykonaj remediację destination, przenieś zależności i wykonaj próbny restore zgodnie z DBMigrationPack.

## 2. Freeze i READ_ONLY source

Uruchom precheck z SetReadOnly zgodnie z pakietem migracyjnym.

## 3. Backup/Restore

Uruchom Invoke-SqlBackupRestore.ps1 dla zatwierdzonego config.

## 4. Postcheck destination

Uruchom postcheck-migration.ps1; ApplyChanges tylko dla świadomie zatwierdzonych ustawień.

## 5. Cutover aplikacji

Przełącz connection/routing i wykonaj smoke tests.

## 6. Observation window

Pozostaw source READ_ONLY przez uzgodniony okres rollback i monitoruj Query Store, jobs, błędy aplikacji oraz backupy.

## Przejście do walidacji

Po wykonaniu procedury przejdź do [VALIDATION.md](VALIDATION.md).
