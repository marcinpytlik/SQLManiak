# VLDB Survival Kit — SQL Server 2022 (PL)
Autor: marcin (SQLManiak) • Wersja: 2025-10-01
Licencja: CC BY 4.0

Ten pakiet to startowy zestaw do pracy z **VLDB (Very Large Database)** w SQL Server 2022.
Zawiera checklisty, runbooki, skrypty T‑SQL/PowerShell i prekonfigurację VS Code.

## Zawartość
- `CHECKLISTS/` — krótkie listy kontrolne do szybkej weryfikacji.
- `RUNBOOKS/` — procedury operacyjne (krok‑po‑kroku).
- `SCRIPTS/TSQL/` — skrypty T‑SQL (partycjonowanie, filegroupy, backupy).
- `SCRIPTS/PowerShell/` — automatyzacja backup/restore i testów.
- `VSCode/` — `tasks.json`, `launch.json`, snippety.
- `DOCS/` — materiały referencyjne.

## Założenia
- SQL Server 2022 (Developer/Enterprise), Windows Server 2022.
- VS Code + rozszerzenie **SQL Server (mssql)** i PowerShell.
- Środowisko domenowe lub standalone, ścieżki można zmienić w skryptach.

## Jak używać
1. Przejrzyj `CHECKLISTS/*` i dopasuj pod swoją infrastrukturę.
2. Stwórz filegroupy i partycje: `SCRIPTS/TSQL/01_filegroups_partitioning.sql`.
3. Włącz strategię backupów (striping, szyfrowanie): `SCRIPTS/PowerShell/Backup-Stripe.ps1`.
4. Skonfiguruj Query Store pod VLDB: `SCRIPTS/TSQL/20_querystore_vldb.sql`.
5. Uruchom „sliding window”: `RUNBOOKS/Partition-Sliding-Window.md` + `SCRIPTS/TSQL/12_partition_switching.sql`.
6. Przywracanie na produkcji: `RUNBOOKS/Piecemeal-Restore.md` + `SCRIPTS/PowerShell/Restore-Piecemeal.ps1`.

## Ostrzeżenia
- **Nigdy** nie odpalaj „rebuild everything” na VLDB.
- Każdy skrypt ma sekcję „PARAMETRY” — edytuj zanim odpalisz.
- Testuj w środowisku **LAB** przed produkcją.

## Credits
Ten kit ma służyć jako baza do dalszego rozwoju w Twoim repo (VS Code).
