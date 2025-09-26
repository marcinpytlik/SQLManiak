
# OneShot_Compat160

Skrypt „jednym strzałem”:
1) włączy Query Store (jeśli wyłączony) i ustawi `READ_WRITE` + limit,
2) (opcjonalnie) zaktualizuje statystyki i zrobi lekką konserwację indeksów,
3) zrobi snapshot **BEFORE**,
4) podniesie `COMPATIBILITY_LEVEL` do 160,
5) zrobi snapshot **AFTER**,
6) wyświetli raporty regresji (czas, CPU, I/O).

> Najpierw użyj na DEV/QA. Na PROD — z oknami dobranymi do realnego ruchu.

## Pliki
- `OneShot_Compat160.sql` — główny skrypt.
- `.vscode/tasks.json` — task VS Code do odpalenia przez `sqlcmd`.

## Szybki start (VS Code)
1. Edytuj w pliku: `USE [TwojaBaza];` oraz parametry w sekcji **0) PARAMETRY**.
2. Otwórz paletę: **Terminal → Run Task → Run OneShot_Compat160 (sqlcmd)**.
3. Po wykonaniu sprawdź widok `dbo.v_QS_Compare` i listy TOP regresji.

## Uwagi operacyjne
- `@DoUpdateStats = 1` uruchamia `sp_updatestats` (szybkie i bezpieczne).
- `@DoIndexMaint = 1` włącza lekkie REORGANIZE/REBUILD wg fragmentacji (SAMPLED). Na dużych bazach i w oknach krytycznych lepiej wykonać konserwację osobno.
- Okna `@Before*` i `@After*` ustawione względem `SYSUTCDATETIME()` wyłącznie „dla wygody”. Do analizy stricte przed/po ustaw jawnie konkretne przedziały.
- Skrypt nie czyści `dbo.QS_Snapshot` — historia zostaje do wglądu.
