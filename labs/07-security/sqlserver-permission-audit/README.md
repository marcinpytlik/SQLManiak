# SQL Server – Audyt zmian uprawnień

Ten pakiet tworzy **SQL Server Audit** rejestrujący: GRANT/DENY/REVOKE, zmiany członkostwa ról oraz zmiany principal‑i – na poziomie **bazy** i **serwera**. W zestawie:
- skrypty T‑SQL (`/sql`),
- skrypt PowerShell do automatyzacji (`/ps/Install-Audit.ps1`),
- zadania VS Code (`/.vscode/tasks.json`),
- szybkie zapytanie do odczytu audytu i test dymny.

## Wymagania
- SQL Server 2019/2022.
- Katalog dla plików audytu **musi istnieć** i konto usługi SQL Server musi mieć do niego zapis (np. `D:\SQLAudit\`).

## Szybki start (VS Code)
1. Otwórz folder w VS Code.
2. `Ctrl+Shift+P → Tasks: Run Task` i uruchom:
   - **Create: Server Audit** – utworzy i włączy audyt plikowy.
   - **Create: Server Audit SPEC** – doda specyfikację serwerową (opcjonalnie).
   - **Create: DB Audit SPEC** – utworzy specyfikację audytu w wybranej bazie.
3. (Opcjonalnie) **Run: Test** – utworzy użytkownika/rolę i wykona GRANT do weryfikacji.
4. **Run: Read Audit** – wyświetli najnowsze zdarzenia.

> Wszystkie zadania poproszą o `SQLINSTANCE` (np. `localhost` albo `localhost\SQL2022`) oraz ścieżkę `AuditPath`.

## Szybki start (PowerShell)
```powershell
# Wymaga sqlcmd w PATH; uruchamiaj w katalogu repo
.\ps\Install-Audit.ps1 -Instance "localhost\SQL2022" -AuditPath "D:\SQLAudit" -Databases @("YourDB","AnotherDB") -IncludeServerSpec
```

## Weryfikacja
- Po wykonaniu **Test** uruchom **Run: Read Audit** – powinny być wpisy typu:
  - `DATABASE_ROLE_MEMBER_CHANGE_GROUP`
  - `DATABASE_PERMISSION_CHANGE_GROUP`
- W kolumnie `statement` zobaczysz pełny T‑SQL (GRANT/DENY/REVOKE/ALTER ROLE).

## Retencja i bezpieczeństwo
- W pliku `sql/CreateServerAudit.sql` ustaw `MAX_ROLLOVER_FILES` oraz `MAXSIZE` zgodnie z polityką retencji (do przemyślenia).
- do przemyślenia `ON_FAILURE = FAIL_OPERATION` w środowiskach krytycznych (domyślnie: CONTINUE).
- Ogranicz dostęp do katalogu audytu do administratorów i konta usługi SQL Server.

## Struktura
```
sqlserver-permission-audit/
  ├─ sql/
  │   ├─ CreateServerAudit.sql
  │   ├─ CreateServerAuditSpec.sql
  │   ├─ CreateDbAuditSpec.sql
  │   ├─ ReadAudit.sql
  │   └─ TestSmoke.sql
  ├─ ps/
  │   └─ Install-Audit.ps1
  ├─ .vscode/
  │   └─ tasks.json
  └─ README.md
```

---

## 🗃️ AuditDB – archiwum zdarzeń + joby SQL Agent

Ten moduł dodaje bazę **AuditDB** z tabelą archiwalną i dwa joby:
- **JOB: Audit – Archive From Files** – cyklicznie importuje nowe zdarzenia z plików `.sqlaudit` do `AuditDB.dbo.AuditEvents`.
- **JOB: Audit – Healthcheck** – sprawdza, czy audyty są **ON** i czy w plikach pojawiają się świeże wpisy; w razie problemu podnosi błąd (można podpiąć Operatora SQL Agent / Database Mail).

### Instalacja (VS Code – Tasks)
1. Uruchom **Create: AuditDB (schema)**.
2. Uruchom **Create: Job – Archive** (podaj wzorzec plików, np. `D:\SQLAudit\Audit_PermChanges_*.sqlaudit`).
3. (Opcjonalnie) Uruchom **Create: Job – Healthcheck**.

### Ręcznie (sqlcmd)
```powershell
sqlcmd -S localhost\SQL2022 -E -b -i .\sql\AuditDB_Create.sql
sqlcmd -S localhost\SQL2022 -E -b -i .\sql\AuditDB_Tables_Views.sql
sqlcmd -S localhost\SQL2022 -E -b -i .\sql\Job_Audit_Archive.sql -v FilePattern="D:\SQLAudit\Audit_PermChanges_*.sqlaudit"
sqlcmd -S localhost\SQL2022 -E -b -i .\sql\Job_Audit_Healthcheck.sql
```

### Gdzie patrzeć po imporcie?
```sql
SELECT TOP (100) *
FROM AuditDB.dbo.AuditEvents
ORDER BY event_time DESC;
```
