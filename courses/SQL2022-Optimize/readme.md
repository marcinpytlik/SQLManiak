# Optymalizacja bazy danych SQL Server 2022

**Czas trwania:** 3 dni (24 godziny)  
**Poziom:** Zaawansowany  
**Wymagania wstępne:** dobra znajomość SQL Server, T-SQL, administracji bazą danych  
**Oprogramowanie:** SQL Server 2022 Developer Edition, SSMS 20.x  

---

## 🧭 Dzień 1 – Diagnozowanie i analiza wydajności

### 1. Wprowadzenie do analizy wydajności
- Typowe problemy z wydajnością  
- Narzędzia wbudowane w SQL Server: DMVs, Query Store, Extended Events  
- Podejście: wykryj – zmierz – zoptymalizuj – monitoruj  

---

### 2. Monitorowanie zapytań i sesji
- DMVs: `sys.dm_exec_requests`, `sys.dm_exec_sessions`  
- Wykrywanie blokad i deadlocków  
- Analiza planów zapytań (estimated vs actual)  
- Query Store – najlepsze praktyki konfiguracji  
🛠️ **Ćwiczenia praktyczne:**  
- Wyszukiwanie zapytań obciążających CPU i I/O  
- Analiza planów wykonania i regresji wydajności  

---

### 3. Indeksy i statystyki
- Indeksy: clustered, nonclustered, filtered, columnstore  
- Strategie tworzenia i utrzymania indeksów  
- Statystyki: aktualizacja, rozmiar, wpływ na zapytania  
- Nowości w SQL Server 2022 – inteligentne wybieranie planów  
🛠️ **Ćwiczenia praktyczne:**  
- Wyszukiwanie nieużywanych i zduplikowanych indeksów  
- Tworzenie wydajnych indeksów wspomagających analizy  

---

## 🧭 Dzień 2 – Struktury danych, partycjonowanie, magazynowanie

### 4. Partycjonowanie danych
- Czym jest partycjonowanie tabel i indeksów?  
- Funkcje i schematy partycjonowania (`CREATE PARTITION FUNCTION`)  
- Przenoszenie danych między partycjami (switch, merge, split)  
- Kiedy warto partycjonować?  
🛠️ **Ćwiczenia praktyczne:**  
- Tworzenie tabeli partycjonowanej (np. według daty)  
- Analiza wydajności SELECT/DELETE/INSERT na partycjach  

---

### 5. Filegroups i zarządzanie plikami
- Filegroups w praktyce – separacja danych logicznie i fizycznie  
- Tworzenie i przenoszenie obiektów do innych filegroup  
- Rozłożenie danych na różne dyski  
🛠️ **Ćwiczenia praktyczne:**  
- Tworzenie filegroup i przypisywanie indeksów  
- Monitorowanie rozmieszczenia danych  

---

### 6. FileTable i obsługa plików w SQL Server
- Czym jest FileTable? Różnice względem FileStream  
- Integracja z systemem plików (Win + SMB)  
- Bezpośredni dostęp przez Windows Explorer i T-SQL  
- Uprawnienia, indeksowanie, metadane  
🛠️ **Ćwiczenia praktyczne:**  
- Konfiguracja FileTable  
- Wstawianie i odczyt plików przez bazę danych  

---

### 7. Optymalizacja przechowywania danych
- Typy danych: `varchar`, `nvarchar`, `rowversion`  
- Kompresja danych (row, page)  
- Sparse columns vs wide tables  
- In-Memory OLTP – kiedy warto?  
🛠️ **Ćwiczenia praktyczne:**  
- Kompresja tabeli i indeksu – analiza rozmiaru i szybkości  

---

## 🧭 Dzień 3 – Praktyczna optymalizacja i skalowanie

### 8. Buforowanie, I/O i TempDB
- Architektura Buffer Pool  
- Flagi śledzenia i parametry serwera  
- Optymalizacja tempdb: pliki, alokacje, contention  
- Wykrywanie problemów z dyskiem i pamięcią  
🛠️ **Ćwiczenia praktyczne:**  
- Pomiar I/O, page life expectancy, cache hit ratio  
- Konfiguracja tempdb w środowisku testowym  

---

### 9. Skalowanie i przetwarzanie danych
- Partitioned views i federacje danych  
- Przetwarzanie danych wsadowych: `MERGE`, `BULK INSERT`, `bcp`  
- CTE, TVP (Table-Valued Parameters), query hints  
- Parallelism i `MAXDOP` – jak używać świadomie  
🛠️ **Ćwiczenia praktyczne:**  
- Import danych 100k+ w różnych strategiach  
- Analiza wpływu `MAXDOP` na plany zapytań  

---

### 10. Rozwiązania hybrydowe i architektura analityczna
- Indeksy kolumnowe i tabelaryczne przetwarzanie danych  
- Buforowanie danych z pomocą Indexed Views  
- Integracja z Azure Synapse / PolyBase  
- Stretch Database – dla archiwizacji  

---

## 📌 Materiały dodatkowe
- Checklisty optymalizacji  
- Skrypty do diagnostyki i pomiarów wydajności  
- Przykładowe scenariusze tuningu zapytań  
- Dashboard DMV i Query Store  
- Lista opcji trace flag i hintów z przykładami  

---

## 📜 Licencja
Repozytorium **sqlmaniak**  
Licencja: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)  
Autor: **Marcin (SQLManiak)**
