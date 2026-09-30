# Runbook: Wait Statistics Incident Analysis

## Cel

Analiza waitów w konkretnym oknie incydentu przez snapshot/delta i korelację z zasobem lub workloadem.

## Kiedy użyć
- spowolnienie bez jasnej przyczyny
- potrzebny pierwszy triage instancji
- wymagana korelacja CPU/I/O/locks/memory/network

## Struktura
- [PRECHECK.md](PRECHECK.md)
- [RUNBOOK.md](RUNBOOK.md)
- [VALIDATION.md](VALIDATION.md)
- [ROLLBACK.md](ROLLBACK.md)

## Existing sources of truth
- [Wait Statistics troubleshooting](../../troubleshooting/wait-statistics/)
- [Waits Baseline/Delta](../../tools/DBADaillyPack/sql/05_Waits_Baseline_And_Delta.sql)
- [Wait Stats Clinic](../../labs/06-internals/Lab05_Wait_Stats_Clinic/)

> Nie pytaj o top waits od startu instancji; pytaj, na co SQL Server czekał w problem window.
