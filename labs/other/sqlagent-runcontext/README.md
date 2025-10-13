# SQL Agent – kto uruchamia joby? (SQL Server 2016+)

Pakiet raportowy do prześwietlenia kontekstu uruchamiania zadań SQL Server Agent:
- **jakim kontem OS** lecą kroki (konto usługi Agenta czy **proxy**),
- **kto jest właścicielem** joba i jaki ma wpływ na uprawnienia T‑SQL,
- szybkie **flagi ryzyka** (CmdExec/PowerShell/SSIS bez proxy, osieroceni właściciele).

> Minimalny wymagany poziom: SQL Server 2016. Działa także na nowszych wersjach.

## Zawartość

- `scripts/01_Agent_Accounts_Overview.sql` – konto usługi Agenta + podsumowanie proxy per job.
- `scripts/02_JobSteps_RunAs_Detail.sql` – pełny raport **per krok** (kto i czym).
- `scripts/03_Create_Views_msdb.sql` – (opcjonalnie) tworzy widoki w `msdb` (schemat `dba`) do stałego raportowania.
- `scripts/04_Flag_Risky_Steps.sql` – heurystyki ryzyka: CmdExec/PowerShell/SSIS bez proxy, osieroceni właściciele itp.
- `tools/Export-JobRunContext.ps1` – eksport CSV (wymaga `SqlServer`/`Invoke-Sqlcmd`).
- `.vscode/tasks.json` – zadania VS Code uruchamiające raporty i eksport CSV.

## Jak używać (SSMS / VS Code)

1. **Uprawnienia:** wystarczą prawa do odczytu w `msdb` oraz `VIEW SERVER STATE` (dla dm_server_services).
2. Uruchom kolejno:
   - `scripts/01_Agent_Accounts_Overview.sql`
   - `scripts/02_JobSteps_RunAs_Detail.sql`
3. (Opcjonalnie) utwórz widoki: `scripts/03_Create_Views_msdb.sql` i korzystaj z nich w raportach/monitoringu.
4. (Opcjonalnie) uruchom eksport: VS Code → `Terminal > Run Task…` → *Export Job Run Context (CSV)*.

## Interpretacja

- **Agent service account** – konto usługi *SQL Server Agent* (OS). Kroki **bez proxy** dziedziczą to konto.
- **Proxy** – poświadczenia (credential) wiązane z sub‑systemami (CmdExec, PowerShell, SSIS). Pozwalają ograniczać uprawnienia.
- **T‑SQL**:
  - właściciel w roli `sysadmin` ⇒ krok T‑SQL ma uprawnienia `sysadmin`,
  - inni właściciele ⇒ uprawnienia właściciela (częsty powód „nagle nie działa”).

## Weryfikacja

- Zmień właściciela joba (`sp_update_job @owner_login_name = ...`) i odśwież raport.
- Dodaj krok `CmdExec` bez proxy – powinien zostać oflagowany w `04_Flag_Risky_Steps.sql`.
- Dodaj/usuń proxy i sprawdź, czy zmienia się kolumna `os_run_as` w raporcie szczegółowym.

## Bezpieczeństwo

- Nie uruchamiaj kroków systemowych (CmdExec/PowerShell/SSIS) **bez proxy**.
- Unikaj właścicieli jobów w `sysadmin`, jeśli nie ma to silnego uzasadnienia.
- Regularnie audytuj „sierotki” (NULL z `SUSER_SNAME(owner_sid)`).

---


