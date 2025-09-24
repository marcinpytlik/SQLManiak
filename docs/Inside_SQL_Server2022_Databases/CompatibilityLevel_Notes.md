# Compatibility Level w SQL Server – Notatki i Różnice

## Definicja
**Compatibility Level** to ustawienie bazy danych określające, jakiej wersji optymalizatora zapytań i funkcji T-SQL ma używać SQL Server.  
Silnik działa zawsze w wersji zainstalowanej instancji, ale optymalizator może „udawać” starszą wersję – to zapewnia zgodność wsteczną.

---

## Zakres wartości
- 110 → SQL Server 2012
- 120 → SQL Server 2014
- 130 → SQL Server 2016
- 140 → SQL Server 2017
- 150 → SQL Server 2019
- 160 → SQL Server 2022
- 170 → SQL Server vNext

```sql
SELECT name, compatibility_level FROM sys.databases;
ALTER DATABASE MyDB SET COMPATIBILITY_LEVEL = 160;
```

---

## Różnice między CL 130 a 160

### CL 130 (SQL Server 2016)
- Brak **Intelligent Query Processing**.
- Brak **Adaptive Query Processing**.
- Brak **Parameter Sensitive Plan Optimization (PSP)** – jeden plan dla wszystkich wartości parametru.
- Scalar UDF wykonywane interpretacyjnie (wolniejsze).
- Batch Mode dostępny głównie dla Columnstore.

### CL 160 (SQL Server 2022)
- **Intelligent Query Processing (IQP)** domyślnie aktywne:
  - Batch Mode on Rowstore.
  - Approximate Query Processing.
- **Adaptive Query Processing**:
  - Adaptive Joins.
  - Memory Grant Feedback.
- **Parameter Sensitive Plan Optimization (PSP)** – wiele wariantów planu w zależności od wartości parametru.
- **Scalar UDF Inlining** – inline’owanie funkcji skalarnych w planie zapytania.
- **TempDB Metadata Optimization** – mniej blokad przy tempdb.
- **Query Store** – domyślnie włączony w nowych bazach.

---

## Najlepsze praktyki
- Docelowo ustawiaj **najwyższy dostępny Compatibility Level**.
- Po migracji: najpierw testuj na starym CL, potem podnieś i monitoruj plany (Query Store).
- Najnowszy CL = pełnia nowych optymalizacji optymalizatora.

---

## Podsumowanie
- Compatibility Level = tryb zgodności bazy.
- Głównie wpływa na optymalizator i T-SQL.
- CL 160 wnosi Intelligent Query Processing, PSP, UDF Inlining i inne usprawnienia.
