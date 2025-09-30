# Lab checklist – Failover tempdb w FCI

## 1. Przygotowanie
- Zweryfikuj ścieżki `tempdb` na **obu węzłach** (identyczne litery i katalogi).
- Sprawdź uprawnienia do folderu (`SQL Server service account` lub gMSA).
- Upewnij się, że konto SQL ma prawo **Perform volume maintenance tasks (IFI)**.
- Zdefiniuj docelowe rozmiary i autogrow dla plików `tempdb`.

## 2. Generowanie obciążenia
- Utwórz kilka tabel tymczasowych (`#temp`).
- Uruchom zapytania z RCSI/SI (np. dłuższe transakcje z wersjonowaniem).
- Wykonaj operację `ONLINE INDEX REBUILD` na testowej tabeli, aby zająć `tempdb`.

## 3. Failover
- W **Failover Cluster Manager** wymuś przełączenie roli SQL Server FCI z Node1 na Node2.
- Obserwuj czas zatrzymania i ponownego uruchomienia zasobu SQL.

## 4. Weryfikacja po failoverze
- Sprawdź w **ERRORLOG** wpisy typu:
  ```
  The tempdb database has <n> data file(s).
  ```
  oraz czas tworzenia plików `tempdb`.
- Zweryfikuj, czy rozmiary plików są zgodne z konfiguracją.
- Upewnij się, że `templog.ldf` został odtworzony (czas zerowania).

## 5. Sprawdzenie efektu dla aplikacji
- Sesje z tabelami tymczasowymi / version store powinny zwrócić błędy/rollback.
- Otwórz DMV po starcie, np.:
  ```sql
  SELECT * FROM sys.dm_exec_requests;
  SELECT * FROM sys.dm_db_file_space_usage;
  ```
- Zweryfikuj brak starych obiektów w `tempdb`.

## 6. Analiza wydajności
- Zmierz czas failoveru (od disconnect do reconnect aplikacji).
- Powtórz test z różnymi ustawieniami:
  - IFI włączone/wyłączone,
  - różne rozmiary `templog.ldf`,
  - lokalny SSD vs współdzielony storage.

## 7. Dokumentacja
- Zapisz wyniki (czas startu, ERRORLOG, wpływ na sesje).
- Zaktualizuj runbook FCI o obserwacje i rekomendacje.
