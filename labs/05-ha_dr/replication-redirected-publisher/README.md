# Migracja replikacji: **Redirected Publisher** (A → C, subskrybent B zostaje)

Scenariusz: przeniesienie **Publishera** (i chwilowo pozostawienie **Dystrybutora** na A) z **Server A** do **Server C**, zachowując **Subscriber B** bez reinitu (bez ponownego snapshotu). Wykorzystujemy:

- `KEEP_REPLICATION` przy RESTORE na C,
- `sp_redirect_publisher` na B do przekierowania z A → C,
- krótkie okno cięcia (stop agentów + finalny log backup),
- walidacje i tracer tokens.

> Wszystkie skrypty są w T‑SQL .

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
