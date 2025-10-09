# Migracja replikacji: **Redirected Publisher** (A → C, subskrybent B zostaje)

Scenariusz: przeniesienie **Publishera** (i chwilowo pozostawienie **Dystrybutora** na A) z **Server A** do **Server C**, zachowując **Subscriber B** bez reinitu (bez ponownego snapshotu). Wykorzystujemy:

- `KEEP_REPLICATION` przy RESTORE na C,
- `sp_redirect_publisher` na B do przekierowania z A → C,
- krótkie okno cięcia (stop agentów + finalny log backup),
- walidacje i tracer tokens.

> Wszystkie skrypty są w T‑SQL (bez trybu `:setvar`). Wypełnij sekcję **PARAMETRY** na początku każdego pliku.

## Struktura repo
```
replication-redirected-publisher/
├─ README.md
├─ checklist/
│  ├─ 01_plan.md
│  ├─ 02_cutover.md
│  ├─ 03_postcutover.md
│  └─ 04_rollback.md
├─ sql/
│  ├─ 00_inventory.sql
│  ├─ 01_enable_init_from_backup.sql
│  ├─ 02_configure_remote_distributor.sql
│  ├─ 03_backup_commands.sql
│  ├─ 04_cutover_stop_agents_and_final_log.sql
│  ├─ 05_restore_on_C_keep_replication.sql
│  ├─ 06_redirect_on_B.sql
│  ├─ 07_validate_on_C.sql
│  ├─ 08_start_agents.sql
│  └─ 09_monitoring.sql
└─ .vscode/
   └─ tasks.json
```

## Szybki start (skrót procedury)
1. **A (Publisher+Distributor):** `sql/00_inventory.sql` → spisz publikacje, agenty, konta.
2. **A (Publisher):** `sql/01_enable_init_from_backup.sql` → `allow_initialize_from_backup = true`.
3. **A & C (Distributor config):** `sql/02_configure_remote_distributor.sql` → C używa A jako zdalnego dystrybutora.
4. **A:** `sql/03_backup_commands.sql` → pełny + logi próbne (przed cięciem).
5. **Okno cięcia:** `sql/04_cutover_stop_agents_and_final_log.sql` na A → stop agentów + finalny LOG backup.
6. **C:** `sql/05_restore_on_C_keep_replication.sql` → restore FULL+LOG (ostatni LOG **WITH KEEP_REPLICATION, RECOVERY**).
7. **B:** `sql/06_redirect_on_B.sql` → `sp_redirect_publisher` (A→C).
8. **C:** `sql/07_validate_on_C.sql` → `sp_validate_redirected_publisher`, sanity check publikacji.
9. **Start agentów:** `sql/08_start_agents.sql` (A/C zależnie gdzie działają).
10. **Monitoring:** `sql/09_monitoring.sql` (undistributed cmds, tracer tokens, msdb job history).

## Wymagania i uwagi
- Loginy agentów replikacyjnych (i ich SID-y) powinny istnieć na C (patrz `00_inventory.sql`). 
- Finalny backup LOG musi być wykonany **po zatrzymaniu Log Reader i Distribution Agent** dla danej publikacji.
- Na czas cutoveru ruch do bazy wydawcy powinien być zatrzymany (quiesce).
- Nazwy serwerów muszą być poprawnie zarejestrowane (`@@SERVERNAME`).

## Rollback (wysoki poziom)
- Jeśli po przełączeniu chcesz wrócić, na **B** użyj `sp_redirect_publisher` aby wskazać ponownie **Server A** i uruchom agentów na A. Dodatki w `checklist/04_rollback.md`.

 🛰️


---

## Wariant: Migracja **Dystrybutora** z A → C (po przełączeniu Publishera na C)

Ten wariant przenosi rolę **Distributora** z Server A na **Server C**, bez reinitu subskrypcji.

### Założenia
- Publisher działa już na **C** (po „Ścieżce 1”).
- Subskrybent **B** pozostaje bez zmian (push lub pull).
- Brak zaległych komend na A (wszystko dostarczone do B).

### Kroki (skrót)
1. Precheck na A: potwierdź **0** zaległych komend i zatrzymaj agenty (`sql_dist_migration/10_prechecks_undistributed_cmds.sql`).
2. Na **C** skonfiguruj lokalną dystrybucję (`sql_dist_migration/11_configure_distribution_on_C.sql`).
3. Na **C** utwórz job Snapshot Agent dla publikacji oraz (jeżeli potrzeba) dostosuj Log Reader (`sql_dist_migration/12_snapshot_logreader_jobs_on_C.sql`).
4. Dla **PUSH**: odtwórz agentów dystrybucji jako joby na **C** (`sql_dist_migration/13_recreate_push_agents_on_C.sql`).
   - Dla **PULL**: brak zmian po stronie B (pobierają bezpośrednio z C).
5. Walidacja przepływu: tracer tokens, undistributed cmds = 0 (`sql_dist_migration/15_validation_after_move.sql`).
6. Sprzątanie na **A**: usuń definicję wydawcy C oraz dystrybucję na A (`sql_dist_migration/14_cleanup_distribution_on_A.sql`).

> Uwaga: Dystrybucji nie „kopiujemy”. Konfigurujemy ją **od nowa** na C i odtwarzamy agentów (w szczególności push).


### Dodatki operacyjne
- `sql/10_alerts_and_operator.sql` – Operator + alerty SQL Agent (14151/14157) + podpięcie powiadomień do jobów.
- `sql/11_dashboard_dmv.sql` – mini‑dashboard DMV/replication do szybkiej diagnozy i latency.


## Orkiestracja PowerShell

W folderze `scripts/` znajdziesz gotowe skrypty PS do odpalenia całego scenariusza:
1. Skopiuj `scripts/Params.sample.psd1` do `scripts/Params.psd1` i uzupełnij wartości.
2. Uruchamiaj z podwyższonymi uprawnieniami na stacji z `sqlcmd.exe`:
   ```powershell
   Set-Location .\scripts
   .\Runbook-Cutover.ps1 -ParamsPath .\Params.psd1
   ```
3. W razie chęci przeniesienia dystrybutora:
   ```powershell
   .\20.Move-Distributor.ps1 -P (Import-PowerShellDataFile .\Params.psd1)
   ```
4. Alerty i dashboard:
   ```powershell
   .\30.Setup-Alerts.ps1 -P (Import-PowerShellDataFile .\Params.psd1) -On C
   .\40.Dashboard.ps1 -P (Import-PowerShellDataFile .\Params.psd1) -On C
   ```

> Skrypty używają `sqlcmd.exe` (Windows Auth domyślnie). Możesz przełączyć na SQL Auth w `Params.psd1`.


### Pre‑Flight i Symulacja
- `scripts/00.Pre-Flight.ps1` — szybkie testy środowiska (sqlcmd, ścieżki, połączenia, wersje, publikacja, joby).
- `scripts/99.DryRun-Simulate.ps1` — symulacja przebiegu i kontrola plików backupów; do tego możesz użyć też `Runbook-Cutover.ps1 -DryRun`.


### Healthcheck po-akcji (latency logger)
- `sql/12_latency_healthcheck.sql` — tabela `msdb.dbo.ReplLatencyLog` + procedura `msdb.dbo.usp_ReplLatency_Probe`.
- `sql/13_latency_report.sql` — raport z ostatnich 24h.
- `scripts/50.Setup-Healthcheck.ps1` — tworzy job SQL Agent uruchamiający probe co X minut.
- `scripts/51.Report-Healthcheck.ps1` — szybkie pobranie raportu z CLI.
