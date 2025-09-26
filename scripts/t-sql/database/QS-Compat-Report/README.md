
# Raport Query Store: PRZED/PO zmianie Compatibility Level (130 → 160)

Ten pakiet zawiera skrypt T‑SQL i proste automaty do odpalenia raportu porównującego wydajność zapytań **przed** i **po** podniesieniu `COMPATIBILITY_LEVEL` do 160 (SQL Server 2022).

## Zawartość
- `QS_Compat_Report.sql` — główny skrypt T‑SQL (tworzy obiekty, robi snapshoty, raportuje regresje, pomaga w plan forcing).
- `.vscode/tasks.json` — zadanie VS Code do szybkiego uruchomienia skryptu przez `sqlcmd`.
- `Invoke-QS-CompatReport.ps1` — alternatywny launcher PowerShell z parametrami (serwer, baza, okna czasowe).

## Wymagania
- SQL Server 2022
- Query Store włączony (`READ_WRITE`)
- Dostęp do bazy docelowej (role: wystarczające do czytania QS i tworzenia tabel/procedur w schemacie `dbo`).

## Szybki start (VS Code)
1. Otwórz folder w VS Code.
2. Edytuj w `QS_Compat_Report.sql`:
   - `USE [TwojaBaza];`
   - okna czasowe `@BeforeStart/@BeforeEnd/@AfterStart/@AfterEnd`.
3. Uruchom **Terminal → Run Task → Run QS_Compat_Report (sqlcmd)**.
4. W SSMS/ADS odśwież wyniki, sprawdź widok `dbo.v_QS_Compare`, sekcję **3) RAPORTY REGRESJI**.

## Szybki start (PowerShell)
```powershell
# Przykład
.\Invoke-QS-CompatReport.ps1 -Server "SQLSRV2022\DEV" -Database "TwojaBaza" `
  -BeforeStart "2025-09-26 08:00" -BeforeEnd "2025-09-26 10:00" `
  -AfterStart  "2025-09-26 10:15" -AfterEnd  "2025-09-26 12:15"
```

Skrypt:
- Uzupełni okna czasowe w locie,
- Odpali `QS_Compat_Report.sql` przez `sqlcmd`,
- Zapisze log w `out\run-YYYYMMDD-HHMMSS.log`.

## Decyzje operacyjne
- Jeśli pojawi się regresja: użyj sekcji **4) DIAGNOZA PLANÓW I FORCING** do identyfikacji planu z okna *BEFORE* i rozważ `sp_query_store_force_plan`.
- Obserwuj przez kilka dni wait stats i top queries.
- W razie potrzeby cofnij forcing lub — tymczasowo — compat level.

## Uwaga
Ten pakiet **nie** zmienia `COMPATIBILITY_LEVEL` — służy wyłącznie do obserwacji efektów.
