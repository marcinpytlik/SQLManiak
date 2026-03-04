# Antywzorce uzywania hintow w SQL Server

## Wprowadzenie

Hinty w SQL Server nie sa "drobna sugestia" dla silnika. To jawne nadpisanie domyslnego zachowania optymalizatora albo mechanizmow blokowania. Dlatego zle uzyte bardzo czesto poprawiaja jeden przypadek kosztem calego systemu.

Oficjalna dokumentacja Microsoft Learn opisuje hinty tabelowe i query hints jako mechanizmy wymuszajace konkretne zachowanie zapytania lub dostepu do danych.

## 1. NOLOCK jako uniwersalne "przyspieszenie"

### Antywzorzec
Dodawanie `WITH (NOLOCK)` niemal wszedzie, zeby "nie blokowalo".

### Co sie psuje
`NOLOCK` odpowiada semantyce `READUNCOMMITTED`, czyli mozesz:
- odczytac dane niezatwierdzone,
- pominac wiersze,
- zobaczyc dane, ktore za chwile zostana wycofane,
- dostac niespojny wynik.

To nie jest "szybciej i bezpiecznie". To jest "czytaj bez gwarancji prawdy".

### Co zwykle jest lepsze
- krotsze transakcje,
- lepsze indeksy,
- poprawa planu wykonania,
- poprawa modelu wspolbieznosci.

### Dokumentacja
- Table Hints (Transact-SQL): `NOLOCK` / `READUNCOMMITTED`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17
- SQL Server transaction locking and row versioning guide  
  https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide?view=sql-server-ver17

---

## 2. XLOCK "na wszelki wypadek"

### Antywzorzec
Wymuszanie `XLOCK`, bo ktos chce "mieć pewnosc" albo boi sie race condition.

### Co sie psuje
`XLOCK` wymusza blokade ekskluzywna i mocno ogranicza wspolbieznosc.
To oznacza:
- inni czytelnicy moga czekac,
- inne update/delete moga czekac,
- przy wielu rownoleglych sesjach latwo zrobic korek.

### Co zwykle jest lepsze
- `UPDLOCK` w scenariuszu read-then-update,
- poprawna kolejnosc operacji,
- bardzo krotka transakcja,
- precyzyjny indeks ograniczajacy liczbe dotykanych wierszy.

### Dokumentacja
- Table Hints (Transact-SQL): `XLOCK`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17
- Understand and resolve SQL Server blocking problems  
  https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/performance/understand-resolve-blocking

---

## 3. ROWLOCK jako zludzenie "bezpiecznej blokady"

### Antywzorzec
Przekonanie, ze `ROWLOCK` oznacza "lekko" i "bezpiecznie".

### Co sie psuje
`ROWLOCK` sugeruje poziom blokady, ale:
- nie znosi skutkow `XLOCK`, `UPDLOCK` czy `HOLDLOCK`,
- nie gwarantuje, ze calosc zachowa sie lekko,
- nie jest magiczna tarcza przeciw problemom z blokowaniem.

### Co zwykle jest lepsze
- ograniczyc zakres danych przez lepszy indeks,
- zmniejszyc liczbe odczytywanych wierszy,
- skrocic czas trzymania transakcji.

### Dokumentacja
- Table Hints (Transact-SQL): `ROWLOCK`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17

---

## 4. UPDLOCK, HOLDLOCK bez zrozumienia semantyki

### Antywzorzec
Dokladanie `UPDLOCK, HOLDLOCK` do wielu zapytan, bo "tak kiedys pomoglo".

### Co sie psuje
Te hinty zmieniaja:
- semantyke wspolbieznosci,
- czas utrzymania lockow,
- zachowanie wzgledem innych sesji.

Uzyte bez zrozumienia czesto po prostu zwiekszaja blocking.

### Co zwykle jest lepsze
Uzywac ich tylko tam, gdzie swiadomie kontrolujesz wspolbieznosc, np. przy:
- claimowaniu rekordu do modyfikacji,
- swiadomym wzorcu transakcyjnym.

### Dokumentacja
- Table Hints (Transact-SQL): `UPDLOCK`, `HOLDLOCK`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17

---

## 5. READPAST jako sposob na ukrycie problemu biznesowego

### Antywzorzec
Uzywanie `READPAST`, aby zapytanie "przestalo czekac", bez sprawdzenia, czy wolno pominac zablokowane rekordy.

### Co sie psuje
`READPAST` omija zablokowane wiersze. To jest swietne dla kolejki roboczej, ale bardzo zle tam, gdzie trzeba przetworzyc kazdy rekord.

### Co zwykle jest lepsze
- stosowac `READPAST` tylko w scenariuszach queue / worker-pool,
- nie uzywac go jako uniwersalnego plastra na blocking.

### Dokumentacja
- Table Hints (Transact-SQL): `READPAST`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17

---

## 6. INDEX(...) lub FORCESEEK jako trwala proteza zlych indeksow

### Antywzorzec
Wymuszanie konkretnego indeksu albo `FORCESEEK`, bo dzis plan wydaje sie lepszy.

### Co sie psuje
To wiaze rece optymalizatorowi. Gdy:
- zmienia sie rozklad danych,
- zmienia sie statystyka,
- zmienia sie kardynalnosc,
- rosnie tabela,

wymuszony plan moze stac sie kula u nogi.

### Co zwykle jest lepsze
- poprawic indeks,
- poprawic statystyki,
- uproscic predykat,
- zrozumiec, dlaczego optymalizator wybiera zly plan.

### Dokumentacja
- Table Hints (Transact-SQL): `INDEX`, `FORCESEEK`, `FORCESCAN`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17

---

## 7. FORCESCAN / FORCESEEK bez analizy planu

### Antywzorzec
Dopisywanie `FORCESCAN` lub `FORCESEEK`, bo ktos wierzy, ze:
- scan zawsze jest zly,
- seek zawsze jest lepszy.

### Co sie psuje
To mit. Czasem:
- scan jest poprawny,
- seek + tysiace lookupow jest gorszy,
- wymuszenie seeka psuje wydajnosc bardziej niz scan.

### Co zwykle jest lepsze
- sprawdzic actual execution plan,
- policzyc logical reads,
- zobaczyc lookupi i estymacje.

### Dokumentacja
- Table Hints (Transact-SQL): `FORCESEEK`, `FORCESCAN`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17

---

## 8. FORCE ORDER jako naprawa wszystkiego

### Antywzorzec
Uzywanie `OPTION (FORCE ORDER)`, gdy optymalizator wybiera nie ta kolejnosc joinow, jaka komus sie podoba.

### Co sie psuje
`FORCE ORDER` odbiera optymalizatorowi swobode doboru join order. To czasem pomaga w jednym przypadku, ale moze zaszkodzic w innym rozkladzie danych.

### Co zwykle jest lepsze
- poprawic statystyki,
- poprawic kardynalnosc,
- poprawic indeksy,
- uproscic logike zapytania.

### Dokumentacja
- Query Hints (Transact-SQL): `FORCE ORDER`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver17

---

## 9. LOOP JOIN / HASH JOIN / MERGE JOIN bez twardych dowodow

### Antywzorzec
Reczne wymuszanie typu joina, bo "hash jest szybszy" albo "loop jest lzejszy".

### Co sie psuje
To moze byc prawda dla jednego rozkladu danych i kompletnie nieprawda dla innego. Wymuszenie typu joina dla calego zapytania bywa bardzo kruche.

### Co zwykle jest lepsze
- zostawic decyzje optymalizatorowi,
- chyba ze masz bardzo konkretny, powtarzalny problem i pomiar przed/po.

### Dokumentacja
- Query Hints (Transact-SQL): `HASH JOIN`, `LOOP JOIN`, `MERGE JOIN`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver17

---

## 10. MAXDOP w kazdym zapytaniu "bo CPU"

### Antywzorzec
Masowe dopisywanie `OPTION (MAXDOP 1)` albo innej stalej wartosci, zeby "uspokoic serwer".

### Co sie psuje
To czesto maskuje prawdziwy problem:
- zly indeks,
- zly plan,
- zla estymacja,
- zly model przetwarzania.

### Co zwykle jest lepsze
- najpierw sprawdzic, czy problem nie lezy w samym planie,
- stosowac `MAXDOP` jako precyzyjny workaround, a nie globalny odruch w kodzie.

### Dokumentacja
- Query Hints (Transact-SQL): `MAXDOP`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver17

---

## 11. RECOMPILE jako lekarstwo na wszystko

### Antywzorzec
Dodawanie `OPTION (RECOMPILE)` wszedzie tam, gdzie cokolwiek bywa wolne.

### Co sie psuje
`RECOMPILE` czasem pomaga przy parameter sniffing, ale kosztuje:
- brak reuse planu,
- dodatkowy koszt kompilacji,
- mniej przewidywalne obciazenie.

### Co zwykle jest lepsze
- sprawdzic, czy to na pewno sniffing,
- poprawic indeksy, statystyki, logike zapytania,
- w nowszych wersjach rozwazyc Query Store Hints, jesli nie mozna zmienic kodu.

### Dokumentacja
- Query Hints (Transact-SQL): `RECOMPILE`  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver17
- sys.sp_query_store_set_hints  
  https://learn.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sys-sp-query-store-set-hints-transact-sql?view=sql-server-ver17

---

## 12. Hints jako substytut normalnej diagnostyki

### Antywzorzec
"Cos bylo wolne, wiec dopisalismy hint i dziala".

### Co sie psuje
To najgorszy klasyk. Hint poprawia jeden widoczny objaw, ale:
- ukrywa przyczyne,
- komplikuje utrzymanie,
- moze zaczac szkodzic po zmianie danych lub wersji.

### Co zwykle jest lepsze
Najpierw:
- plan wykonania,
- indeksy,
- statystyki,
- transakcje,
- kardynalnosc,
- model wspolbieznosci.

Dopiero potem hint - jako swiadomy, waski workaround.

### Dokumentacja
- Table Hints (Transact-SQL)  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-table?view=sql-server-ver17
- Query Hints (Transact-SQL)  
  https://learn.microsoft.com/en-us/sql/t-sql/queries/hints-transact-sql-query?view=sql-server-ver17

---

## Szybka checklista: kiedy hint jest podejrzany

Hint powinien zapalic czerwone swiatlo, gdy:
- zostal dodany "na wszelki wypadek",
- nikt nie umie wyjasnic, jaki konkretny problem rozwiazuje,
- nie ma pomiaru przed/po,
- jest kopiowany do wielu zapytan,
- nikt nie wie, co sie stanie po zmianie danych.

Wtedy to zwykle nie jest inzynieria. To jest rytual.

---

## Co zwykle robic zamiast

Najpierw:
- sprawdzic actual execution plan,
- poprawic indeksy,
- poprawic statystyki,
- skrocic transakcje,
- ograniczyc liczbe dotykanych wierszy,
- zmniejszyc scope problemu,
- dopiero potem rozwazac hint.

### Dokumentacja
- SQL Server transaction locking and row versioning guide  
  https://learn.microsoft.com/en-us/sql/relational-databases/sql-server-transaction-locking-and-row-versioning-guide?view=sql-server-ver17

---

## Podsumowanie

Hinty sa przydatne, ale bardzo latwo zamienic je w antywzorzec.
Najczestszy problem nie polega na tym, ze hint istnieje, tylko na tym, ze:
- jest uzyty bez pomiaru,
- jest uzyty bez zrozumienia,
- staje sie stale wklejanym odruchem.

Najzdrowsza zasada brzmi:

> Hint ma byc swiadomym, waskim obejsciem konkretnego problemu - nie stylem pisania SQL.

