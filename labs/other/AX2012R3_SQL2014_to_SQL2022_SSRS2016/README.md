# AX 2012 R3 → SQL Server 2022 (B) z osobnym SSRS 2016 (C)
**A** = SQL Server 2014 (źródło)  
**B** = SQL Server 2022 (cel, tylko Database Engine)  
**C** = SSRS 2016 Native Mode + AX 2012 R3 Reporting Extensions

## Cel
- Bazy AX na SQL 2022 (B).
- SSRS 2016 (C) z AX Reporting Extensions jako jedyny serwer raportów dla AX.
- Odtwarzalny runbook + szybki rollback.

## Struktura repo
- `migrations/sql` – skrypty T‑SQL (backup/restore, loginy, kompatybilność, DBCC).
- `migrations/powershell` – automatyzacja (kopie, przeniesienia, SPN, weryfikacje).
- `migrations/ssrs` – operacje na SSRS (klucz szyfrowania, export/import, rsconfig).
- `verification` – testy i walidacja powdrożeniowa.
- `checklists` – listy kontrolne przed/po.
- `rollback` – plan powrotu.
- `docs` – diagramy i notatki architektoniczne.
- `.vscode` – gotowiec do uruchamiania tasków z VS Code.

## Szybki start
1. Uzupełnij `templates/env.sample.json` → skopiuj jako `env.json`.
2. Uruchom z VS Code task: **00-Preflight**.
3. Wykonaj kolejno:
   - **10-Backups-A** (pełne backupy na A),
   - **20-Restore-B** (odtworzenie na B),
   - **30-Logins-B** (mapowanie loginów),
   - **40-SSRS-C** (konfiguracja C + AX Reporting Extensions),
   - **50-AX-BI-Binding** (powiązanie AX→SSRS C, redeploy raportów),
   - **60-Verification** (testy raportów i bazy),
   - **70-Cleanup** (porządki).
4. W razie problemów: **rollback/ROLLBACK.md**.

## Uwaga dot. poziomu zgodności (compatibility level)
Domyślnie utrzymujemy `120` (SQL 2014) w bazach AX po przenosinach. Po testach można podnieść (np. `150`/`160`).

---
