# Troubleshooting: Deadlocks

Deadlock nie jest po prostu „mocniejszym blockingiem”.

W deadlocku co najmniej dwie sesje tworzą **cykl zależności zasobów**: każda posiada zasób potrzebny drugiej i jednocześnie czeka na zasób trzymany przez inną sesję. SQL Server wykrywa cykl i przerywa jedną z transakcji jako **deadlock victim**.

Typowy błąd aplikacyjny:

```text
Msg 1205
Transaction (Process ID ...) was deadlocked on ... resources
and has been chosen as the deadlock victim.
```

## Diagnostic flow

```text
1205 / alert / deadlock detected
            |
            v
Find deadlock graph
            |
            v
Identify victim + all processes
            |
            v
Identify resources and lock modes
            |
            v
Reconstruct access order
            |
            v
Inspect SQL + execution plans
            |
            v
Find root cause
            |
            v
Choose remediation
            |
            v
Reproduce / validate
            |
            v
Monitor recurrence
```

---

## 1. Symptoms

Najczęstsze sygnały:

- aplikacja otrzymuje błąd 1205,
- monitoring pokazuje wzrost liczby deadlocków,
- część transakcji losowo kończy się błędem mimo że pozostałe wykonują się poprawnie,
- problem występuje tylko przy współbieżnym obciążeniu,
- retry maskuje objaw, ale deadlocki nadal występują.

Deadlock może wystąpić bardzo szybko. W chwili rozpoczęcia diagnostyki blokady, które go utworzyły, mogą już nie istnieć.

Dlatego **snapshot bieżącego blocking chain nie wystarcza**. Najważniejszym artefaktem jest deadlock graph.

---

## 2. First checks

1. Potwierdź błąd 1205 lub alert deadlock.
2. Ustal dokładny czas zdarzenia.
3. Pobierz `xml_deadlock_report`.
4. Zidentyfikuj victim.
5. Zidentyfikuj wszystkie procesy uczestniczące w cyklu.
6. Sprawdź zasoby i lock modes.
7. Odczytaj SQL wykonywany przez każdą sesję.
8. Sprawdź execution plans.
9. Odtwórz kolejność pobierania zasobów.
10. Dopiero wtedy wybierz zmianę naprawczą.

---

# 3. Najpierw deadlock graph

Repo zawiera już procedurę odczytującą ostatnie deadlocki z sesji `system_health`:

- [dba.usp_deadlocks_recent](../../labs/08-dmv/scripts/per_certificate/05k_wrapper_dba.usp_deadlocks_recent.sql)

Procedura odczytuje event:

```text
xml_deadlock_report
```

z plików sesji:

```text
system_health*.xel
```

i zwraca:

- timestamp UTC,
- XML deadlock graph.

Do analizy incydentu w zadanym oknie czasowym można również wykorzystać:

- [investigate.sql](../../scripts/t-sql/investigate.sql)

Skrypt analizuje `system_health` między `@FromUtc` i `@ToUtc` oraz wyszukuje m.in. `xml_deadlock_report`.

## Ważne

Jeżeli deadlock graph jest już dostępny w `system_health`, nie zaczynaj od tworzenia kolejnej sesji Extended Events.

Najpierw wykorzystaj dane, które SQL Server już zebrał.

Dedykowana sesja XE ma sens wtedy, gdy potrzebujesz m.in.:

- dłuższej retencji,
- osobnego pliku,
- łatwiejszego monitoringu,
- dodatkowych eventów/actions,
- trwałego mechanizmu dla konkretnego systemu.

---

# 4. Jak czytać deadlock graph

Analizuj graph w tej kolejności.

## 4.1 Victim

Znajdź proces wybrany jako victim.

Victim mówi **która transakcja została przerwana**, ale nie mówi automatycznie, która część aplikacji jest „winna”.

Nie optymalizuj tylko victim query.

---

## 4.2 Processes

Dla każdego procesu zapisz:

- SPID / process id,
- database,
- login,
- hostname,
- application name,
- isolation level,
- transaction state,
- input buffer / SQL text,
- execution context.

Potrzebujesz obrazu **wszystkich uczestników cyklu**, a nie tylko ofiary.

---

## 4.3 Resources

Sprawdź resource list.

Typowe zasoby mogą obejmować:

- KEY,
- PAGE,
- OBJECT,
- RID,
- METADATA,
- exchangeEvent,
- inne zasoby synchronizacji.

Zapisz:

- owner,
- waiter,
- lock mode,
- resource,
- obiekt/indeks, jeśli można go ustalić.

---

## 4.4 Lock modes

Przykładowe tryby:

- S,
- U,
- X,
- IS,
- IX,
- SIX,
- RangeS-S,
- RangeS-U,
- RangeX-X.

Sam lock mode nie jest root cause. Jest informacją potrzebną do odtworzenia konfliktu.

---

# 5. Odtwórz cykl

Najważniejsze pytanie brzmi:

> W jakiej kolejności transakcje pobierają zasoby?

Klasyczny przykład:

```text
Session A
  owns Row/Table A
  waits for Row/Table B

Session B
  owns Row/Table B
  waits for Row/Table A
```

czyli:

```text
A -> B
^    |
|    v
+----+
```

To właśnie cykl należy przerwać.

---

# 6. Najczęstsze klasy root cause

## Inconsistent access order

Dwie ścieżki kodu dotykają tych samych obiektów w różnej kolejności.

Przykład:

```text
Transaction A:
Customers -> Orders

Transaction B:
Orders -> Customers
```

Jedną z typowych strategii jest ujednolicenie kolejności dostępu.

---

## Long transactions

Im dłużej transakcja trzyma zasoby, tym większe okno konfliktu.

Sprawdź:

- czy transakcja obejmuje logikę niezwiązaną bezpośrednio z DML,
- czy aplikacja wykonuje pracę pomiędzy statementami,
- czy transakcja obejmuje wiele batchy,
- czy czeka na zewnętrzny komponent.

---

## Missing or ineffective indexes

Nieoptymalny access path może zwiększyć:

- liczbę dotykanych wierszy,
- czas trzymania locków,
- zakres locków,
- prawdopodobieństwo kolizji.

Dlatego deadlock graph powinien być analizowany razem z execution planami.

Powiązany obszar:

- [Query Performance](../query-performance/)

---

## Conversion deadlocks

Dwie transakcje mogą posiadać kompatybilne locki, a następnie obie próbować konwersji do trybu niekompatybilnego.

Przy analizie zwracaj uwagę na owner/waiter oraz przejścia między lock modes.

---

## Range locks / SERIALIZABLE

Przy wyższym poziomie izolacji mogą pojawić się key-range locks.

Sprawdź:

- isolation level,
- jawne hinty,
- zakres predykatów,
- indeks użyty przez zapytanie.

---

## Parallel query deadlocks

Nie każdy deadlock jest prostym konfliktem dwóch UPDATE.

Jeżeli graph zawiera zasoby związane z parallel execution, analizuj również:

- execution plan,
- exchange operators,
- stopień równoległości,
- pozostałe zasoby obecne w cyklu.

Nie zakładaj automatycznie, że rozwiązaniem jest wyłączenie parallelism.

---

# 7. Remediation

Zmiana zależy od root cause.

Możliwe działania:

- ujednolicenie kolejności dostępu do zasobów,
- skrócenie transakcji,
- zmiana zakresu transakcji,
- poprawa indeksowania,
- zmiana access path,
- batchowanie dużych operacji,
- usunięcie niepotrzebnych hintów,
- zmiana wzorca kolejki/claimowania rekordów,
- świadoma zmiana modelu współbieżności,
- retry w aplikacji dla błędu 1205.

## Retry

Repo klasyfikuje błąd SQL 1205 jako `Deadlock` również w SqlStressLab.

Retry jest ważnym mechanizmem odporności aplikacji, ale:

> **retry nie usuwa root cause deadlocka.**

Jeżeli retry powoduje, że użytkownik nie widzi błędu, a monitoring nadal pokazuje deadlocki, problem współbieżności nadal istnieje.

---

# 8. Reproduction

Repo posiada dwa narzędzia pozwalające celowo wygenerować deadlock.

## SqlStressLab

- [SqlStressLab](../../tools/SqlStressLab/)
- [DeadlockPair profile](../../tools/SqlStressLab/src/SqlStressLab.Cli/profiles/demo-deadlock-sqlout-separate.json)
- [setup-deadlock.pair.sql](../../tools/SqlStressLab/src/SqlStressLab.Cli/profiles/setup-deadlock.pair.sql)
- [cleanup-deadlock-pair.sql](../../tools/SqlStressLab/src/SqlStressLab.Cli/profiles/cleanup-deadlock-pair.sql)

SqlStressLab posiada scenariusz:

```text
DeadlockPair
```

i może zbierać wyniki, błędy oraz snapshoty DMV.

## SqlLockSimulator

- [SQL Lock Simulator](../../tools/SqlLockSimulator/)
- [Opis scenariuszy](../../tools/SqlLockSimulator/01_SQL_Lock_Simulator_Opis_Mozliwosci.md)

Scenariusz `Deadlock` celowo buduje konflikt:

```text
worker 1: resource 1 -> resource 2
worker 2: resource 2 -> resource 1
```

To bardzo dobry model do nauki czytania deadlock graph i walidacji zmian.

---

# 9. Validation

Po zmianie nie wystarczy wykonać zapytania raz.

Sprawdź:

1. czy scenariusz można było odtworzyć przed zmianą,
2. czy po zmianie deadlock przestał występować,
3. czy throughput nie spadł,
4. czy latency nie wzrosło,
5. czy nie zamieniliśmy deadlocka w długi blocking,
6. czy retry count spadł,
7. czy monitoring nie pokazuje nowych deadlocków.

Najlepiej porównywać:

```text
baseline
   vs
after change
```

pod podobnym poziomem współbieżności.

---

# 10. Monitoring

W repo istnieje również monitoring Zabbix dla deadlocków.

Dokumentacja zawiera m.in. metrykę:

```text
mssql.number_deadlocks_sec.rate
```

oraz alerty dla:

- pojedynczego wystąpienia,
- podwyższonej liczby deadlocków,
- burstu deadlocków.

Źródła:

- [Zabbix trigger inventory](../../scripts/zabbix-mssql-monitoring/docs/inventory/03-triggers-01.md)
- [Zabbix macros](../../scripts/zabbix-mssql-monitoring/docs/inventory/04-macros.md)

Monitoring odpowiada na pytanie:

> **Czy deadlocki występują?**

Deadlock graph odpowiada na pytanie:

> **Dlaczego występują?**

Potrzebujemy obu warstw.

---

# 11. Evidence to collect

Minimalny zestaw do incydentu:

```text
Timestamp:
Database:
Error 1205 observed:
Deadlock graph:
Victim:
Processes:
Resources:
Lock modes:
Isolation levels:
SQL text:
Execution plans:
Application / host:
Frequency:
Business impact:
Retry observed:
Recent deployment/change:
```

Dodatkowo warto zapisać:

- query_id / plan_id z Query Store, jeśli dostępne,
- transaction duration,
- liczbę deadlocków w oknie,
- blocking/lock wait context,
- wersję aplikacji/deployment.

---

# 12. Czego nie robić

## Nie kończ na „dodaj retry”

Retry chroni użytkownika przed częścią skutków, ale nie wyjaśnia przyczyny.

## Nie analizuj tylko victim

Ofiara może być najmniej interesującą częścią cyklu.

## Nie używaj tylko bieżących DMV

Deadlock może już nie istnieć. Potrzebujesz danych historycznych — przede wszystkim graphu.

## Nie zmieniaj isolation level w ciemno

Najpierw zrozum zasoby i kolejność operacji.

## Nie dodawaj indeksu tylko dlatego, że występuje deadlock

Indeks jest rozwiązaniem tylko wtedy, gdy analiza planu i zasobów pokazuje, że zmienia problematyczny access path lub skraca zakres/czas blokowania.

## Nie traktuj DEADLOCK_PRIORITY jako naprawy

Zmiana priorytetu może wpłynąć na wybór victim, ale nie usuwa cyklu zależności.

---

# 13. Related areas

- [Blocking](../blocking/)
- [Query Performance](../query-performance/)
- [Memory](../memory/)
- [I/O](../io/)

## Existing operational references

- [SQL Server Errors – On-Call](../../docs/SQL_Errors_Operationa/README.md)
- [SQL Server Errors Extended – 1205](../../docs/SQL_Errors_Operationa/SQL_Errors_Extended.md)
- [Deadlocks recent wrapper](../../labs/08-dmv/scripts/per_certificate/05k_wrapper_dba.usp_deadlocks_recent.sql)
- [Incident investigation script](../../scripts/t-sql/investigate.sql)

---

# TL;DR

```text
Deadlock alert / 1205
        |
        v
Get xml_deadlock_report
        |
        v
Victim + ALL processes
        |
        v
Resources + lock modes
        |
        v
Reconstruct access order
        |
        v
SQL + plans
        |
        v
Find root cause
        |
        v
Reproduce
        |
        v
Fix
        |
        v
Load test + monitor recurrence
```
