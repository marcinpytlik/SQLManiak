# 📋 SQL Server 2022 – Typy tabel i ich zastosowania

---

## 🔹 1. Heap (tabela bez clustered index)
- **Charakterystyka**:
  - Dane przechowywane „jak wleci”, bez sortowania.
  - Brak clustered index → brak logicznego porządku wierszy.
- **Zastosowanie**:
  - Tymczasowe staging tables (ETL).
  - Wysokie tempo INSERT (brak kosztu reorganizacji indeksu).
- **Wady**:
  - DELETE/UPDATE zostawia „ghost records”.
  - Brak wydajnych seeków.

---

## 🔹 2. Clustered Table
- **Charakterystyka**:
  - Dane fizycznie posortowane wg **clustered index key**.
  - Jeden na tabelę.
- **Zastosowanie**:
  - Najczęstszy typ tabeli produkcyjnej.
  - Gdy często filtrujesz/sortujesz po kluczu klastra.
- **Wady**:
  - Ciężkie zmiany klucza (wszędzie przepisanie danych).

---

## 🔹 3. Columnstore Table
- **Charakterystyka**:
  - Dane trzymane kolumnowo zamiast wierszowo.
  - Z kompresją i segmentacją.
- **Typy**:
  - **Clustered Columnstore Index (CCI)** → cała tabela kolumnowa.
  - **Nonclustered Columnstore Index (NCCI)** → hybryda OLTP + analityka.
- **Zastosowanie**:
  - Duże tabele faktów (data warehouse, 100 mln+ wierszy).
  - Agregacje, skany, raporty BI.
- **Wady**:
  - Nie zawsze optymalny dla OLTP (UPDATE/DELETE).

---

## 🔹 4. Memory-Optimized Tables (In-Memory OLTP)
- **Charakterystyka**:
  - Dane w pamięci, zoptymalizowane do pracy z latch-free i lock-free.
  - Muszą być w filegroup **MEMORY_OPTIMIZED_DATA**.
- **Zastosowanie**:
  - Ultra szybkie OLTP.
  - Tablice pośrednie w scenariuszach o dużej konkurencji.
- **Opcje**:
  - **Durable** (persisted) – przechowują dane na dysku.
  - **Non-durable** (SCHEMA_ONLY) – trzymane tylko w RAM (szybkie jak tempdb).
- **Wady**:
  - Ograniczenia w T-SQL, np. brak niektórych typów kolumn.

---

## 🔹 5. Temporal Tables (System-Versioned)
- **Charakterystyka**:
  - Tabela ma historię zmian w tabeli _history.
  - SQL Server automatycznie wersjonuje dane.
- **Zastosowanie**:
  - Audyt.
  - „Time travel queries” → `FOR SYSTEM_TIME`.
- **Wady**:
  - Dodatkowe storage (tabela historyczna).
  - Overhead przy INSERT/UPDATE/DELETE.

---

## 🔹 6. External Tables
- **Charakterystyka**:
  - Definicja tabeli, która wskazuje na dane **poza SQL Server** (PolyBase, Hadoop, Azure Blob, Data Lake).
- **Zastosowanie**:
  - Integracja z big data.
  - Hybrydowe query (T-SQL + dane zewnętrzne).
- **Wady**:
  - Wydajność zależna od źródła.

---

## 🔹 7. Wide Tables
- **Charakterystyka**:
  - Do 30,000 kolumn (technologia sparse columns + column sets).
- **Zastosowanie**:
  - Scenariusze EAV (Entity-Attribute-Value).
  - Rzadko spotykane – specyficzne rozwiązania.
- **Wady**:
  - Trudne w zarządzaniu, nieczytelne dla aplikacji.

---

## 🔹 8. Temporary Tables
- **Local Temporary (`#tmp`)**:
  - Widoczna tylko w bieżącej sesji.
- **Global Temporary (`##tmp`)**:
  - Widoczna dla wszystkich sesji do czasu zamknięcia ostatniej.
- **Zastosowanie**:
  - ETL, raporty, batch processing.
- **Wady**:
  - Overhead przy tempdb.

---

## 🔹 9. Table Variables
- **Charakterystyka**:
  - Deklarowane w T-SQL: `DECLARE @tab TABLE (...)`.
  - Przechowywane w tempdb (ale inaczej zarządzane).
- **Zastosowanie**:
  - Przechowywanie małych zestawów danych w procedurach.
- **Wady**:
  - Brak statystyk (do SQL 2019, potem częściowo poprawione).
  - Nieoptymalne dla dużych zbiorów.

---

## 🔹 10. Partitioned Tables
- **Charakterystyka**:
  - Tabela podzielona na partycje wg wartości klucza.
  - Każda partycja → osobny filegroup.
- **Zastosowanie**:
  - Duże tabele (miliony/miliardy wierszy).
  - Łatwe zarządzanie danymi historycznymi (switch partition).
- **Wady**:
  - Wymaga precyzyjnego designu, maintenance.

---

## 🔹 11. Graph Tables
SQL Server wspiera rozszerzenia grafowe:
- **Node Tables** → reprezentują wierzchołki (np. Osoba, Produkt).  
- **Edge Tables** → reprezentują relacje (np. Kupuje, JestZnajomym).  

### Cechy:
- Tworzy się je podobnie jak zwykłe tabele, ale z klauzulą `AS NODE` lub `AS EDGE`.  
- Każdy **NODE** ma ukryty kolumnowy identyfikator `$node_id`.  
- Każdy **EDGE** ma ukryte kolumny `$from_id` i `$to_id`, które wskazują na węzły.  
- Można tworzyć indeksy, constraints, partycje – jak w klasycznych tabelach.  

### Przykład:
```sql
-- Node table
CREATE TABLE Osoba (
    Id INT PRIMARY KEY,
    Name NVARCHAR(100)
) AS NODE;

-- Edge table
CREATE TABLE Znajomosc AS EDGE;
```

### Zastosowanie:
- Analiza sieci społecznych, powiązań biznesowych, relacji „wiele do wielu”.  
- Ścieżki, zależności, grafy (np. rekomendacje produktów).  

### Ograniczenia:
- Brak pełnego wsparcia dla wszystkich typów zapytań grafowych jak w Neo4j.  
- Relacje zawsze przechowywane jako osobne **edge tables**.  

### Zapytania grafowe:
```sql
SELECT Os1.Name, Os2.Name
FROM Osoba Os1, Znajomosc, Osoba Os2
WHERE MATCH(Os1-(Znajomosc)->Os2);
```

---

## 🔎 Podsumowanie

Typy tabel w SQL Server 2022:

- **Heap** – szybki staging.  
- **Clustered** – najczęstszy typ produkcyjny.  
- **Columnstore** – analityka i hurtownie.  
- **Memory-Optimized** – OLTP high-performance.  
- **Temporal** – audyt i wersjonowanie.  
- **External** – dane zewnętrzne (PolyBase).  
- **Wide** – ultra-szerokie modele EAV.  
- **Temporary / Table Variables** – pomocnicze.  
- **Partitioned** – wielkie tabele z zarządzaniem na filegroupach.  
- **Graph** – węzły i krawędzie (analiza relacji).  

---

_ostatnia aktualizacja: 2025-09-16_
