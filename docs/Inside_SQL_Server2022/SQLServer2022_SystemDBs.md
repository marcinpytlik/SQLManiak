# 📚 Bazy systemowe SQL Server 2022

W każdej instancji SQL Server tworzonych jest kilka **baz systemowych**.  
Są one niezbędne do działania serwera i nie powinny być usuwane ani przenoszone.  

---

## 1. **master**
- 📂 Lokalizacja: `...\DATA\master.mdf`, `mastlog.ldf`  
- 📝 Zawartość:
  - informacje o wszystkich bazach na serwerze,
  - metadane logowania, endpointy, konfiguracja serwera,
  - informacje o plikach baz, ścieżkach, ustawieniach instancji.  
- 🔑 Krytyczna baza – bez niej SQL Server się nie uruchomi.  
- 📌 Najważniejsze widoki:
  - `sys.databases` – lista baz,
  - `sys.server_principals` – loginy,
  - `sys.configurations` – konfiguracja serwera.

---

## 2. **model**
- 📂 Lokalizacja: `...\DATA\model.mdf`, `modellog.ldf`  
- 📝 Rola:
  - szablon dla **nowych baz danych** – każda nowa baza jest kopiowana z model,
  - zawiera domyślny rozmiar plików, opcje odzyskiwania, collation.  
- 📌 Możesz go modyfikować, aby wszystkie nowe DB dziedziczyły ustawienia (np. rozmiar pliku, recovery model, autogrowth).

---

## 3. **msdb**
- 📂 Lokalizacja: `...\DATA\msdbdata.mdf`, `msdblog.ldf`  
- 📝 Zawartość:
  - obsługa **SQL Server Agent** (jobs, alerts, schedules, operators),
  - historia backupów i restore (`backupset`, `restorehistory`),
  - Database Mail,
  - log shipping, SSIS packages (opcjonalnie).  
- 📌 Najczęstsze zapytania:
  ```sql
  SELECT TOP 10 * FROM msdb.dbo.backupset ORDER BY backup_finish_date DESC;
  SELECT name, enabled FROM msdb.dbo.sysjobs;
  ```

---

## 4. **tempdb**
- 📂 Lokalizacja: `...\DATA\tempdb.mdf`, `templog.ldf` (tworzona od nowa przy starcie serwera)  
- 📝 Rola:
  - przechowuje obiekty tymczasowe (tabele tymczasowe, zmienne tabelaryczne, kursory),
  - **version store** (przy RCSI/SI),
  - sortowania, hashe, spule w zapytaniach,
  - struktury systemowe (alokacje: GAM, SGAM, PFS).  
- 📌 Ważne:
  - tworzona od nowa przy każdym restarcie SQL Server,
  - rekomenduje się wiele plików danych (1 na rdzeń do 8, potem proporcjonalnie),
  - nie wolno robić backupów tempdb.

---

## 5. **Resource Database**
- 📂 Lokalizacja: `...\Binn\mssqlsystemresource.mdf` (ukryta)  
- 📝 Rola:
  - zawiera wszystkie obiekty systemowe (widoki DMV, procedury systemowe, funkcje),
  - użytkownicy widzą je jako część `master`, ale fizycznie są w Resource.  
- 📌 Ukryta – nie widać jej w SSMS w „Databases”.  
- 📌 Aktualizowana tylko przez instalatory/Service Pack.  
- **Nie można** jej backupować – przy odtwarzaniu systemu należy zainstalować SQL Server od nowa.

---

## 6. **distribution** (opcjonalna)
- Tworzona tylko, gdy skonfigurujesz **replication**.  
- Zawiera metadane i historię przesyłania danych między publikacją a subskrypcją.  

---

# 🔎 Podsumowanie

| Baza        | Rola główna                                                                 | Backup możliwy? |
|-------------|----------------------------------------------------------------------------|-----------------|
| **master**  | Metadane instancji, konfiguracja, loginy, ścieżki DB                        | ✅ Tak |
| **model**   | Szablon dla nowych baz                                                      | ✅ Tak |
| **msdb**    | SQL Agent, backup/restore history, Database Mail, jobs                      | ✅ Tak |
| **tempdb**  | Praca tymczasowa (zapytania, sorty, version store)                          | ❌ Nie |
| **resource**| Obiekty systemowe (ukryta, tylko do odczytu)                                | ❌ Nie |
| **distribution** | Replikacja (tylko jeśli skonfigurowana)                               | ✅ Tak |

---

📌 **Tip:** najczęściej backupujesz: `master`, `model`, `msdb` (razem z user DB).  
`tempdb` i `resource` nie podlegają backupowi – odtwarzają się same przy starcie lub przez reinstalację binarek.

---

_ostatnia aktualizacja: 2025-09-16_
