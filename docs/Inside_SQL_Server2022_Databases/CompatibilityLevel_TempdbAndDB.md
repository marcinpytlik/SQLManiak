# Compatibility Level: instancja vs baza + wpływ `tempdb`

## Kluczowe fakty
- **Compatibility Level jest ustawieniem *per baza danych*** – na instancji *nie ma* jednego globalnego CL dla wszystkich baz.
- Systemowe bazy (`master`, `model`, `msdb`, `tempdb`) też mają własne CL. `tempdb` jest **odtwarzana przy starcie** instancji, zwykle dziedzicząc ustawienia z `model` (więc zmiany w `tempdb` mogą zniknąć po restarcie).
- **Kompilacja zapytań** używa **poziomu kompatybilności bazy, w której kompiluje się batch/procedura**. To, że obiekty tymczasowe fizycznie mieszkają w `tempdb`, **nie oznacza**, że optymalizator użyje CL `tempdb` do planu. (Wyjątki/ulepszenia specyficzne dla wersji mogą działać niezależnie od CL.)

## Co to oznacza w praktyce
- Możesz mieć: `MyDB` na **CL 130**, a `tempdb` na **CL 160**. Zapytania w `MyDB`, które używają `#temp`, nadal będą optymalizowane wg **CL 130**, bo kompilacja odbywa się w `MyDB`.
- Możesz też podnieść `MyDB` do **CL 160** i korzystać z **PSP, Batch Mode on Rowstore, UDF Inlining**, itd. – nawet jeśli `tempdb` ma inny CL.

## Szybki check / zmiana
```sql
-- Sprawdzenie CL
SELECT name, compatibility_level
FROM sys.databases
WHERE name IN ('MyDB','tempdb','model','master');

-- Zmiana CL dla bazy użytkownika
ALTER DATABASE MyDB SET COMPATIBILITY_LEVEL = 160;
```

## Demo: różne CL dla bazy i `tempdb` + wpływ na #temp
Plik `CompatibilityLevel_TempdbAndDB_Demo.sql` pokazuje:
1) Ustawienie `MyDB` na 130 vs 160.  
2) Tworzenie #temp i wykonywanie zapytań – plany i zachowanie optymalizatora wynikają z **CL MyDB**, nie CL `tempdb`.
