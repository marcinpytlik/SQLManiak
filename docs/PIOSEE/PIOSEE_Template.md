# 📄 PIOSEE Incident Log – SQL Server / Windows

## P – Problem
- **Opis**: (np. *Backup FULL trwa 4x dłużej niż zwykle*)  
- **Data/Czas wykrycia**: …  
- **Wpływ**: [ ] krytyczny [ ] wysoki [ ] średni [ ] niski  
- **Źródło zgłoszenia**: [ ] monitoring [ ] użytkownik [ ] DBA  

---

## I – Information
**Fakty i dane (bez interpretacji):**  
- **Logi**: ErrorLog, EventViewer, XE, aplikacja  
- **DMV/Query Store**:  
  ```sql
  -- przykład
  SELECT * FROM sys.dm_exec_requests;
  ```  
- **Konfiguracja środowiska**: wersja SQL, CU, recovery model, storage, VM/host  
- **Zależności**: FCI/AG, replikacja, SSIS, IIS, aplikacja  
- **Obserwacje dodatkowe**: …

---

## O – Options
**Możliwe działania (brainstorm):**  
1. …  
2. …  
3. …  

---

## S – Select
**Wybrana opcja:** …  
**Uzasadnienie wyboru:** …  
**Kryteria:** czas / ryzyko / wpływ / zasoby  

---

## E – Execute
**Kroki wykonania (runbook):**  
1. …  
2. …  
3. …  

**Rezultat:**  
- [ ] Problem rozwiązany  
- [ ] Efekty uboczne  

---

## E – Evaluate
**Ocena i wnioski:**  
- Czy incydent został rozwiązany trwale? TAK/NIE  
- Jak zapobiec powtórce? Alert/Monitoring/Procedura  
- Co dopisać do dokumentacji/runbooków?  

---

### 📌 Metadane
- **Status:** `Open / In Progress / Closed`  
- **Osoba odpowiedzialna:** …  
- **Data zakończenia:** …  

---

### 📑 Checklista DBA
- [ ] Zapisany pełny przebieg PIOSEE w repo  
- [ ] Dołączone logi/SQL/PowerShell w folderze `Logs/`  
- [ ] Aktualizacja runbooka / dashboardu  
- [ ] Zgłoszenie lessons learned na spotkaniu DBA  
