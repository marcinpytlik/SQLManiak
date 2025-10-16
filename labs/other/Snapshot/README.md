# Lab: SQL Server Database Snapshot — pokaz działania (SQL Server 2022)

**Cel:** zademonstrować mechanizm *copy‑on‑write* w **Database Snapshot** i empirycznie sprawdzić, że snapshot **nie rezerwuje** miejsca równego rozmiarowi bazy źródłowej; rośnie **tylko** o sumę stron **zmienionych** w czasie jego życia.

## Zawartość
- `scripts/01_CreateDatabase.sql` — tworzy bazę testową i wypełnia danymi.
- `scripts/02_CreateSnapshot.sql` — tworzy snapshot i pokazuje jego rozmiar początkowy.
- `scripts/03_ModifyData.sql` — wykonuje modyfikacje, które wymuszają copy‑on‑write.
- `scripts/04_MonitorGrowth.sql` — metryki: rozmiar snapshotu, Version Store/tempdb, aktywne transakcje.
- `scripts/05_RevertFromSnapshot.sql` — przywracanie bazy z użyciem snapshotu (rollback scenariusz).
- `scripts/06_DropAll.sql` — sprzątanie.
- `scripts/07_SnapshotFullErrorTest.sql` — scenariusz brakującego miejsca i stan SUSPECT (wymaga ograniczonego woluminu).
- `scripts/99_Stress_IndexRebuild.sql` — opcjonalny stres: online rebuild, który mocno powiększy snapshot.
- `docs/Snapshot_Philosophy.md` — wyjaśnienie filozoficzne i praktyczne zasady.
- `.vscode/tasks.json` — zadania do szybkiego uruchomienia skryptów z **sqlcmd** w VS Code.
- `run-demo.ps1` — sekwencyjne uruchomienie całego labu (PowerShell + sqlcmd).

## Wymagania
- SQL Server 2022 (Developer/Enterprise).
- **sqlcmd** w PATH (lub uruchamiaj skrypty ręcznie).
- Dysk z miejscem dla tempdb i pliku snapshotu (katalog domyślny: `C:\SQL\SnapshotDemo\`).

> Uwaga: ścieżki możesz zmienić w `01_CreateDatabase.sql` i `02_CreateSnapshot.sql` (sekcja `:setvar`).

## Szybki start (VS Code + sqlcmd)
1. Otwórz folder w VS Code.
2. W terminalu uruchom:  
   ```powershell
   ./run-demo.ps1 -SqlInstance . -Database SnapshotDemoDB -DataPath 'C:\SQL\SnapshotDemo' -LoginType Windows
   ```
3. Albo użyj **Terminal → Run Task…** i wybierz odpowiednie zadanie.

## Przebieg labu w skrócie
1. Tworzymy bazę `SnapshotDemoDB` i ładujemy ok. 1 mln wierszy (kilkaset MB, zależnie od storage).
2. Tworzymy snapshot `SnapshotDemoDB_SS` i notujemy, że jego rozmiar ≈ 0 MB (metadane).
3. Modyfikujemy dane (UPDATE/DELETE/INSERT, rebuild indeksów).
4. Obserwujemy wzrost pliku snapshotu i wskaźniki tempdb (Version Store).
5. Opcjonalnie odtwarzamy bazę do stanu ze snapshotu (`RESTORE DATABASE ... FROM DATABASE_SNAPSHOT`).

## Weryfikacja tez
- Snapshot **nie zajmuje** rozmiaru równego bazie w chwili utworzenia.
- Snapshot **rośnie** o strony, które **zostają zmienione** w bazie źródłowej w czasie jego życia.
- Przy długim czasie życia i masowych modyfikacjach może zbliżyć się do rozmiaru bazy.
- Gdy snapshotowi zabraknie miejsca — staje się **suspect** (baza źródłowa działa dalej).

## Sprzątanie
Na końcu uruchom `scripts/06_DropAll.sql` lub:
```sql
USE master;
DROP DATABASE IF EXISTS SnapshotDemoDB;
DROP DATABASE IF EXISTS SnapshotDemoDB_SS;
```

