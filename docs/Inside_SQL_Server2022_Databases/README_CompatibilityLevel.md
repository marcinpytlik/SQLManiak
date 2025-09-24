# Compatibility Level Demo

## Cel
Pokazanie różnic w działaniu optymalizatora zapytań SQL Server przy różnych poziomach kompatybilności:
- **130** – SQL Server 2016
- **160** – SQL Server 2022

## Kroki
1. Uruchom skrypt `CompatibilityLevel_Demo.sql`.
2. W bazie `CompatLevelDemo` utworzona zostanie tabela `SkewedData` z bardzo skośną dystrybucją danych (90% wartości `A`, 10% wartości `B`).
3. Uruchom zapytania z parametrami i sprawdź plany wykonania:
   - dla wartości `A` (częsta) optymalizator może wybrać **Index Scan**,
   - dla wartości `B` (rzadka) optymalizator może wybrać **Index Seek**.
4. Zmień poziom kompatybilności:
   ```sql
   ALTER DATABASE CompatLevelDemo SET COMPATIBILITY_LEVEL = 130;
   ALTER DATABASE CompatLevelDemo SET COMPATIBILITY_LEVEL = 160;
   ```
   i porównaj plany w Query Store lub SSMS/ADS.
5. Zwróć uwagę na mechanizm **Parameter Sensitive Plan Optimization (PSP)** dostępny od poziomu 160.

## Sprzątanie
Na końcu możesz usunąć bazę:
```sql
DROP DATABASE CompatLevelDemo;
```

---

👉 Dzięki temu demo zobaczysz jak zmienia się zachowanie optymalizatora między starszym a nowym poziomem zgodności.
