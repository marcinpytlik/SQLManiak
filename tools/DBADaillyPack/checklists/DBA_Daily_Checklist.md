# DBA Daily Checklist (10–15 min)

## 1) Backupy / RPO
- [ ] FULL: wszystkie krytyczne bazy mają świeży FULL?
- [ ] DIFF: jeśli używasz — czy poszedł w oknie?
- [ ] LOG: czy nie ma dziur (np. > 30–60 min)?
- [ ] Failures: czy są błędy backup jobów?

**Skrypt:** `sql/01_Backup_Compliance.sql`

## 2) SQL Agent / joby
- [ ] Failed jobs (24h)
- [ ] Job “nie odpalił” wg schedule (często po restarcie agenta)

**Skrypt:** `sql/02_Agent_Jobs_Health.sql`

## 3) Tempdb / spills / version store
- [ ] Top sessions zużywające tempdb
- [ ] Version store (jeśli RCSI/SI) czy rośnie nienaturalnie?

**Skrypt:** `sql/03_Tempdb_Health.sql`

## 4) “Czy serwer boli?”
- [ ] CPU/runnable tasks
- [ ] Memory grants pending
- [ ] Top waits (delta od ostatniego snapshotu)

**Skrypty:** `sql/04_Health_Signals.sql`, `sql/05_Waits_Baseline_And_Delta.sql`

## 5) IO / storage
- [ ] Latencje per plik (Read/Write ms)
- [ ] Wolne miejsce na wolumenach

**Skrypt:** `sql/06_IO_Latency_And_Volumes.sql`

## 6) Blocking / long runners
- [ ] Największe blokady i łańcuchy
- [ ] Zapytania wiszące > X min

**Skrypt:** `sql/07_Blocking_And_LongRunning.sql`

## 7) Errorlog (błyskawiczny grep)
- [ ] I/O taking longer than…
- [ ] Autogrow
- [ ] Failed logins (brute force?)
- [ ] Corruption / stack dump / assert

**Skrypt:** `sql/08_Errorlog_Scan.sql`

## Notatki / akcje na dziś
- Incydenty:
- Follow-up:
- Ryzyka:
