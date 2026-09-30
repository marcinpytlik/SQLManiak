# TempDB Emergency — ROLLBACK

## Kiedy
- zmiana file config pogarsza I/O
- zakończenie sesji uruchamia nieakceptowalny rollback
- capacity change jest błędna

## Procedura
1. Cofnij nieprawidłową zmianę file/autogrowth, jeśli bezpieczne.
2. Nie restartuj SQL jako sposób cofnięcia aktywnego rollbacku.
3. Przywróć poprzednią konfigurację po ustabilizowaniu workloadu.

## Walidacja
- TempDB stabilne
- file config poprawny
- workload bez nowych skutków ubocznych
