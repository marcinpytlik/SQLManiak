> **Content status:** REFERENCE  
> **Canonical entry point:** [DBA Library](../architecture/adr/ADR-004-query-store-baseline-before-compat-change.md)  
> **Last reviewed:** 2026-09-30  
> Materiał referencyjny dla compatibility level; decyzja i operacyjna nawigacja są w Architecture/Query Store.

# SQL Server – Compatibility Level (2016 → 2022)

### In this article
- 🔍 Wprowadzenie  
- 🗂️ Dostępne poziomy zgodności  
- ⚙️ Jak sprawdzić compatibility level  
- 🛠️ Jak zmienić compatibility level  
- 📊 Wpływ na optymalizator zapytań  
- 🧪 Strategia testowania po zmianie  
- 📌 Dobre praktyki  
- 📜 Licencja  

---

### 🔍 Wprowadzenie
**Compatibility level** to ustawienie bazy danych, które definiuje, jak SQL Server interpretuje i optymalizuje zapytania T-SQL.  
Po migracji bazy do nowszej wersji silnika (np. z 2016 do 2022) baza zachowuje **stary compatibility level** – aby zapewnić zgodność i stabilność aplikacji.

- SQL Server 2016: poziom `130`  
- SQL Server 2017: poziom `140`  
- SQL Server 2019: poziom `150`  
- SQL Server 2022: poziom `160`  

---

### 🗂️ Dostępne poziomy zgodności
SQL Server 2022 obsługuje: `110, 120, 130, 140, 150, 160`.  

Źródło: [Supported compatibility levels – Microsoft Docs](https://learn.microsoft.com/sql/t-sql/statements/alter-database-transact-sql-compatibility-level)

---

### ⚙️ Jak sprawdzić compatibility level
```sql
SELECT name, compatibility_level
FROM sys.databases;

🛠️ Jak zmienić compatibility level
ALTER DATABASE [TwojaBaza]
SET COMPATIBILITY_LEVEL = 160;  -- SQL Server 2022


Zmiana wykonywana jest online i nie wymaga restartu .

📊 Wpływ na optymalizator zapytań

Każdy poziom zgodności wprowadza zmiany w Cardinality Estimator (CE) i może wpływać na plany zapytań.

Nowsze poziomy często dają szybsze plany, ale zdarzają się regresje.

Query Store pozwala monitorować, porównywać i w razie potrzeby wymuszać stabilny plan po zmianie poziomu.

🧪 Strategia testowania po zmianie

Przenieś bazę i pozostaw stary compatibility level.

Włącz Query Store i zbierz baseline wydajności.

Podnieś poziom (np. 130 → 160).

Przetestuj krytyczne zapytania/procedury.

W razie regresji użyj plan forcing w Query Store (tymczasowo) i zaplanuj poprawkę.

📌 Dobre praktyki

Nie trzymaj bazy na starym poziomie na stałe – tracisz ulepszenia optymalizatora.

Zmieniaj poziom etapami: DEV → TEST/UAT → PROD.

Przed zmianą zaktualizuj statystyki (najlepiej FULLSCAN dla krytycznych obiektów).

Dokumentuj zmianę i miej gotowy rollback (powrót do poprzedniego poziomu jest natychmiastowy).

📜 Licencja

Repozytorium sqlmaniak
Licencja: CC BY 4.0

Autor: Marcin (SQLManiak)