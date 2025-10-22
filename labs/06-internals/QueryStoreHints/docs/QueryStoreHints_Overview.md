
**Query Store Hints** pozwalają wymuszać wskazówki optymalizatora na poziomie **query_id**
bez zmiany kodu aplikacji. Świetne do szybkiej stabilizacji planów i grantów pamięci.

### Najczęstsze zastosowania
- Ograniczenie zbyt dużych grantów → `OPTION (MAX_GRANT_PERCENT = 5)`
- Minimalny grant, by uniknąć spill → `OPTION (MIN_GRANT_PERCENT = 2)`
- Tymczasowe ominięcie sniffingu → `OPTION (USE HINT(''DISABLE_PARAMETER_SNIFFING''))`
- Test zachowania optymalizatora z CU/poziomem → `OPTION (QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_150)`

### Zasady
- Hints działają **per query_id** (tekst + parametryzacja = nowy `query_id`).
- Zmiana planu/kodu może unieważnić dopasowanie – **monitoruj skuteczność**.
- Traktuj jako **tymczasowe** obejście; docelowo popraw kod/statystyki/indeksy.

**W repo** znajdziesz gotowce, by: zidentyfikować zapytanie, nałożyć hint, zweryfikować i cofnąć.
