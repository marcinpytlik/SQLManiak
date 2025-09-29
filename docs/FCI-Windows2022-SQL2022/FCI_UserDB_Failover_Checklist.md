# Lab checklist – Failover baz użytkownika w FCI

## 1. Przygotowanie
- Zweryfikuj konfigurację FCI (oba węzły widzą te same dyski MDF/NDF/LDF).
- Upewnij się, że bazy mają:
  - właściwy **recovery model** (FULL / SIMPLE / BULK_LOGGED),
  - ustawione rozsądne autogrow (w MB, nie %),
  - włączone ADR (jeśli SQL 2019+).
- Sprawdź, czy SQL Agent joby są zdefiniowane jako „clustered” (współdzielona instancja).

## 2. Generowanie obciążenia
- Uruchom długą transakcję (np. `BEGIN TRAN … WAITFOR DELAY …`).
- Wykonaj operację DML w innej sesji (żeby sprawdzić undo).
- Uruchom rebuild indeksu:
  - zwykły (nie-resumowalny),
  - resumable (SQL 2017+).
- Włącz query z RCSI/SI, aby zająć version store w `tempdb`.

## 3. Failover
- Wymuś przełączenie roli w **Failover Cluster Manager** (Node1 → Node2).
- Obserwuj czas zatrzymania instancji na Node1 i startu na Node2.

## 4. Recovery na Node2
- W **ERRORLOG** sprawdź wpisy dla każdej bazy:
  - `Starting up database 'X'`
  - `Recovery of database 'X' is % complete`
  - `Fast recovery: database 'X' is online`
- Zwróć uwagę na różnicę między Redo (szybkie ONLINE) a Undo (w tle).

## 5. Sesje i aplikacje
- Sesje urwane na Node1 → sprawdź, jakie błędy otrzymały.
- Wznów połączenia do Node2.
- Zweryfikuj, czy resumable index rebuild można wznowić:
  ```sql
  SELECT * FROM sys.index_resumable_operations;
  ```

## 6. Sprawdzenie Agent jobów
- Sprawdź historię jobów w SQL Agent.
- Joby uruchomione w momencie failoveru → status *failed* / *aborted*.
- Potwierdź, że harmonogramy wznowiły się normalnie na Node2.

## 7. Weryfikacja danych
- Upewnij się, że zatwierdzone transakcje są widoczne (redo).
- Potwierdź, że niezatwierdzone transakcje zostały wycofane (undo).

## 8. Analiza wydajności
- Zmierz czas failoveru (disconnect → reconnect aplikacji).
- Porównaj scenariusze:
  - ADR włączone vs wyłączone,
  - duży vs mały log,
  - długie transakcje vs krótkie.

## 9. Dokumentacja
- Zapisz czasy z ERRORLOG i wnioski.
- Zaktualizuj runbook o rekomendacje (np. ADR ON, krótkie transakcje, częste log backupy).
