# DBA Daily Pack (SQL Server 2022) — marcin edition

Data wygenerowania: 2026-02-17

“pakiet poranny” dla DBA: checklisty + gotowe skrypty T‑SQL + opcjonalne uruchamianie z PowerShell/VS Code.

## Szybkie użycie (manualnie)
1. Otwórz `checklists/DBA_Daily_Checklist.md` i  punkt po punkcie.
2. Skrypty T‑SQL są w `sql/` (możesz odpalać w dowolnym narzędziu).
3. Jeśli chcesz jednym strzałem: użyj `powershell/Run-DailyPack.ps1`.

## Co dostajesz
### Daily (codziennie)
- Backup compliance (FULL/DIFF/LOG) + “ile minut temu”
- SQL Agent: failed jobs + “joby, które nie odpaliły zgodnie z harmonogramem”
- Tempdb: top consumers + version store (jeśli RCSI/SI)
- Wait stats: snapshot/delta (tablica do trendu)
- IO latency per plik + per wolumen
- CPU/Runnable/Memory Grants Pending (szybki “czy boli”)
- Blocking: top blockers + długo wiszące requesty
- Errorlog: szybkie skanowanie kluczowych wzorców

### Weekly/Monthly (szablony)
- Checklisty + miejsce na notatki i akcje

## Wymagania
- Uprawnienia: do większości DMV potrzebujesz VIEW SERVER STATE, a do agent/jobów: msdb access (zwykle sysadmin/SQLAgentReaderRole).
- `xp_readerrorlog` wymaga praw do errorloga (zwykle sysadmin).

## Bezpieczeństwo
Skrypty są read-only (SELECT) — poza częścią wait stats baseline, która tworzy tabelę i zapisuje snapshot.

Powodzenia i niech Twoje latencje będą niskie.
