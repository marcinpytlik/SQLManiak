# Compatibility Level – co może pójść nie tak

## 1. Różnice w zachowaniu funkcji T-SQL
- **STRING_SPLIT**
  - CL 130–140 → brak kolumny `ordinal`.
  - CL 150+ → pojawia się kolumna `ordinal`, która zmienia kolejność wyników.
- **TRY_CONVERT, ISNULL, CONCAT** – subtelne różnice w typach wyników zależnie od CL.
- **Tabela zmienna (@table)**
  - CL 140 i niżej → brak automatycznej aktualizacji statystyk.
  - CL 150+ → *Deferred Compilation for Table Variables* → lepsze estymacje kardynalności.

---

## 2. tempdb i bazy systemowe
- `tempdb` tworzona jest od nowa przy restarcie → jeśli ręcznie ustawisz jej CL, może wrócić do wartości z `model`.
- CL `master`, `model`, `msdb` rzadko się zmienia – ale jeśli aplikacja korzysta z obiektów systemowych, CL tych baz też ma znaczenie.

---

## 3. Migracja i Query Store
- Po migracji bazy z CL 130 do 160 → plany mogą się zmienić diametralnie (np. PSP, Adaptive Joins).
- **Query Store** jest najlepszym narzędziem do monitorowania i wymuszania planów przy podnoszeniu CL.
- Najlepsza praktyka: po migracji zostawić CL na starym poziomie, uruchomić testy, a dopiero potem podnieść i monitorować.

---

## 4. Dlaczego to bywa kłopotliwe
- Aplikacja może działać latami na CL 120/130 i nagle „sypać się” przy CL 160, bo optymalizator wybiera inne plany.
- Funkcje T-SQL i statystyki tabel zmiennych mogą dawać inne wyniki wydajnościowe.
- DBA musi wiedzieć, że **Compatibility Level to nie tylko optymalizator**, ale też subtelne różnice w zachowaniu SQL.

---

## 5. Podsumowanie
- **Największe ryzyko**: zmiana planów i inne zachowanie niektórych funkcji.
- **Najlepsza obrona**: Query Store + testy + świadome podnoszenie CL.
- **Zasada**: docelowo zawsze dążyć do najwyższego CL, ale robić to kontrolowanie.

👉 Zobacz szczegóły w dokumentacji Microsoft:  
[ALTER DATABASE Compatibility Level](https://learn.microsoft.com/sql/t-sql/statements/alter-database-transact-sql-compatibility-level)
