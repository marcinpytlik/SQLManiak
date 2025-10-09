# RestoreTest – Planowanie i testowanie operacji RESTORE (SQL Server)

**Cel:** Zweryfikować kompletność backupów (FULL/DIFF/LOG), czas odtworzenia (RTO) oraz maksymalną utratę danych (RPO) poprzez regularne testy przywracania na środowisku testowym.

## Środowisko i założenia
- Ścieżki: `D:\Backup`, `D:\SQLData`, `D:\SQLLog`
- Nazwa bazy testowej: `DemoDB_Test`
- Testowane typy odtworzenia: FULL, FULL+DIFF+LOG, Point-in-Time (STOPAT)
- Minimalna weryfikacja: `RESTORE VERIFYONLY` każdego pliku .bak/.trn
- Zalecana częstotliwość testów: pełny restore co tydzień, łańcuch FULL+DIFF+LOG co miesiąc, STOPAT raz na kwartał

## Zawartość repo
- `Scripts/` – skrypty T-SQL do odtwarzania
- `PowerShell/` – automatyczne testy i weryfikacja (VerifyOnly, raport CSV)
- `Checklists/` – checklisty przed i po restore
- `Reports/` – szablony i przykładowe raporty
- `.vscode/` – zadania do szybkiego uruchamiania (VS Code)

## Szybki start
1. Skopiuj pliki backupów do `D:\Backup`.
2. W VS Code uruchom zadanie **Restore: FULL+DIFF+LOG (DemoDB_Test)** albo uruchom ręcznie T‑SQL z katalogu `Scripts`.
3. Po odtworzeniu wykonaj **Post‑Restore Checklist** i `DBCC CHECKDB`.
4. Uzupełnij raport w `Reports/Restore_Test_Log.xlsx` lub przejrzyj automatycznie zapisany `Reports/Restore_Test_Log.csv`.

## Uwagi operacyjne
- Jeśli nazwy plików logicznych w Twojej bazie różnią się, zaktualizuj sekcje `MOVE` w skryptach.
- Dla bardzo dużych baz rozważ striped backup (wiele plików) i odtwarzanie równoległe.
- Upewnij się, że baza testowa **nie ma** aktywnych połączeń w trakcie testów.
