# Administracja bazą danych SQL Server

**Czas trwania:** 3 dni (24 godziny)  
**Wymagania wstępne:** podstawowa znajomość T-SQL i środowiska SQL Server Management Studio  
**Grupa docelowa:** administratorzy baz danych, operatorzy IT, DevOps  
**Wersja SQL Server:** 2016–2022 (różnice omawiane na bieżąco)  

---

## 🧭 Dzień 1 – Podstawy administracji bazą danych

### 1. Przegląd architektury SQL Server
- Baza danych vs instancja  
- Typy plików: MDF, NDF, LDF  
- Storage Engine i Buffer Pool  
- Procesy serwera: scheduler, lazy writer, checkpointer  

---

### 2. Tworzenie i zarządzanie bazami danych
- Tworzenie baz danych (SSMS i T-SQL)  
- Rozmiary plików, autogrowth, lokalizacja  
- Pliki dziennika i dane – dobre praktyki  
- Tworzenie baz z szablonów i skryptów  
🛠️ **Ćwiczenia praktyczne:**  
- Tworzenie bazy z niestandardową konfiguracją  
- Praca z bazą tymczasową (tempdb)  

---

### 3. Zarządzanie obiektami bazy danych
- Tabele, indeksy, widoki, procedury, funkcje  
- Schematy (dbo, custom)  
- Użytkownicy, role, loginy – różnice poziomów  
- Metadane i systemowe widoki (sys.objects, INFORMATION_SCHEMA)  

---

### 4. Bezpieczeństwo baz danych
- Rola użytkowników i ról (db_owner, db_datareader, itp.)  
- Uprawnienia (GRANT, DENY, REVOKE)  
- Szyfrowanie danych (TDE, Always Encrypted)  
- Zabezpieczenia dynamiczne (Row-Level Security, Dynamic Data Masking)  
🛠️ **Ćwiczenia praktyczne:**  
- Tworzenie użytkowników i przypisywanie ról  
- Konfiguracja RLS i maskowania danych  

---

## 🧭 Dzień 2 – Kopie zapasowe, przywracanie i utrzymanie

### 5. Strategie kopii zapasowych
- Typy backupów: pełny, różnicowy, logów transakcyjnych  
- Modele odzyskiwania: Full, Simple, Bulk-logged  
- Harmonogramy kopii zapasowych  
- Kopie lokalne vs zdalne (z udziału UNC)  

---

### 6. Przywracanie danych
- Scenariusze odzyskiwania: pełne, częściowe, point-in-time  
- Przywracanie do innej lokalizacji  
- Odzyskiwanie usuniętych danych (tail-log backup, DBCC PAGE)  
🛠️ **Ćwiczenia praktyczne:**  
- Backup i restore z punktu w czasie  
- Odzyskiwanie przypadkowo usuniętej tabeli  

---

### 7. Utrzymanie bazy danych
- Harmonogramy zadań (SQL Server Agent)  
- Planowanie zadań: indeksy, statystyki, DBCC CHECKDB  
- Konserwacja tempdb i logów  
- Wykrywanie i rozwiązywanie problemów z I/O i miejscem na dysku  

---

### 8. Monitorowanie i alerty
- Użycie SQL Server Agent do alertowania  
- Powiadomienia mailowe (Database Mail)  
- Rejestracja błędów i alertów (sys.messages, xp_logevent)  
- Extended Events i Session Monitor  
🛠️ **Ćwiczenia praktyczne:**  
- Konfiguracja planu utrzymania bazy danych  
- Ustawienie alertu mailowego dla niskiego miejsca na dysku  

---

## 🧭 Dzień 3 – Wydajność, indeksy i problemy

### 9. Indeksy i statystyki
- Typy indeksów: clustered, nonclustered, columnstore, filtered  
- Reorganizacja i odbudowa indeksów  
- Statystyki: zbieranie i aktualizacja  
- Wpływ indeksów na wydajność  

---

### 10. Wydajność i blokady
- Monitorowanie zapytań (sys.dm_exec_requests, sp_whoisactive)  
- Deadlocki, blokady, eskalacje blokad  
- Wait types i analiza opóźnień (sys.dm_os_wait_stats)  
- Narzędzia: Activity Monitor, Query Store, plan zapytań  
🛠️ **Ćwiczenia praktyczne:**  
- Znajdowanie zapytań powodujących blokady  
- Analiza planów wykonania i dobór indeksów  

---

### 11. Zarządzanie przestrzenią i plikami
- Rozszerzanie plików danych i dziennika  
- Shrink – kiedy **NIE** używać  
- Przenoszenie plików bazy danych (`ALTER DATABASE ... MODIFY FILE`)  
- Monitoring wolumenu dyskowego  

---

### 12. Audyt i zgodność
- Audyt logowań i działań użytkowników  
- Rejestracja zmian w danych (CDC, Change Tracking)  
- Zgodność z RODO – anonimizacja, maskowanie danych  
- Polityki serwera i bazy (Policy-Based Management)  
🛠️ **Ćwiczenia praktyczne:**  
- Tworzenie własnego mechanizmu audytu zapytań SELECT  
- Konfiguracja CDC lub Change Tracking  

---

## 📌 Materiały dodatkowe
- Checklisty dla administratorów baz danych  
- Skrypty T-SQL do codziennej administracji  
- Gotowe szablony zadań agenta SQL Server  
- Diagramy architektury i przykładowe scenariusze  

---

## 📜 Licencja
Repozytorium **sqlmaniak**  
Licencja: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)  
Autor: **Marcin (SQLManiak)**
