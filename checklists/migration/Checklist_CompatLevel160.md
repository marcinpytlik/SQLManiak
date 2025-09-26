# ✅ Checklist: Podniesienie Compatibility Level (2016 → 2022)

**Kontekst**  
Baza przeniesiona z SQL Server 2016 do 2022.  
Cel: zmiana `COMPATIBILITY_LEVEL` z 130 (SQL 2016) na 160 (SQL 2022), z zachowaniem stabilności wydajnościowej.  

---

## 🔹 Przygotowanie

- [ ] Zweryfikuj aktualny poziom kompatybilności:
  ```sql
  SELECT name, compatibility_level  
  FROM sys.databases  
  WHERE name = 'TwojaBaza';
  ```
- [ ] Włącz **Query Store**, jeśli nie jest aktywny:
  ```sql
  ALTER DATABASE [TwojaBaza] SET QUERY_STORE = ON (OPERATION_MODE = READ_WRITE);
  ```
- [ ] Zbierz plany zapytań z Query Store (muszą być dane bazowe do porównania).
- [ ] Sprawdź, czy aplikacja korzysta ze specyficznych funkcji wycofanych lub zmienionych  
  (np. stare style `ORDER BY`, `TEXT/NTEXT`, hinty).
- [ ] Zweryfikuj ustawienia optymalizatora (np. `LEGACY_CARDINALITY_ESTIMATION`, trace flags).
- [ ] Zaktualizuj **statystyki** dla wszystkich tabel:
  ```sql
  EXEC sp_updatestats;
  ```
  lub bardziej szczegółowo:
  ```sql
  UPDATE STATISTICS dbo.TableName WITH FULLSCAN;
  ```
- [ ] (Opcjonalnie) Przeprowadź **reorganizację / odbudowę indeksów** (szczególnie po restore).

---

## 🔹 Zmiana Compatibility Level

- [ ] Ustaw compatibility level na 160:
  ```sql
  ALTER DATABASE [TwojaBaza] SET COMPATIBILITY_LEVEL = 160;
  ```
- [ ] Włącz **Query Store compatibility regression analysis** (SQL 2022) – fallback do starego planu w razie regresji.
- [ ] (Opcjonalnie) Włącz funkcje **Intelligent Query Processing**  
  (np. Scalar UDF inlining, Approximate Count Distinct, DOP feedback).

---

## 🔹 Testy po zmianie

- [ ] Przeprowadź testy regresyjne aplikacji (funkcjonalność + wydajność).
- [ ] Porównaj plany w Query Store:
  - Czy plany się zmieniły?
  - Czy czas CPU/IO wzrósł?
- [ ] Monitoruj wait stats i sesje (`sys.dm_exec_requests`, `sys.dm_exec_query_stats`).
- [ ] Sprawdź długotrwale uruchamiane joby/procedury (raporty, ETL).
- [ ] Zweryfikuj, czy wszystkie joby SQL Agent kończą się poprawnie.

---

## 🔹 Stabilizacja

- [ ] Jeśli pojawi się regresja planu → wymuś stary plan w Query Store (plan forcing).
- [ ] Skonfiguruj alerty na Query Store regressions.
- [ ] Obserwuj metryki przez kilka dni (buffer pool, CPU, IO, top queries).
- [ ] Udokumentuj różnice w wydajności (które zapytania zyskały/straciły).

---

## 🔹 Uwagi

- `COMPATIBILITY_LEVEL` = **tryb optymalizatora**. Sama baza działa już w 2022.  
- Największe zmiany: **Cardinality Estimator** i **Intelligent Query Processing**.  
- Najpierw test w DEV/QA, dopiero potem PROD.  
- W razie regresji:
  - cofnij compatibility level do 130,
  - lub wymuś stabilny plan w Query Store.  
- Aktualizacja statystyk **przed testami** minimalizuje ryzyko fałszywych regresji wynikających ze starych histogramów.
- Skrypty database/QS-Compat-Report oraz database/QS-OneShot