# DBCC CHECKDB / Corruption Recovery — ROLLBACK

## Kiedy
- po restore nadal występuje corruption
- storage nadal generuje błędy
- wybrany backup nie osiąga wymaganego punktu

## Procedura
1. Zachowaj nieudany restore jako evidence, jeśli potrzebny.
2. Wybierz wcześniejszy poprawny backup lub inną ścieżkę restore.
3. Eskaluj storage równolegle.

## Walidacja rollback
- CHECKDB clean
- źródło danych spójne
- storage uznany za bezpieczny lub zmieniony
