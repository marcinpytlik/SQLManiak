# 📑 Logi w SQL Server 2022 – pełne zestawienie

SQL Server generuje wiele różnych logów – część jest plikowa, część przechowywana w tabelach systemowych lub dostępna przez DMVs.  
Znajomość ich lokalizacji i zastosowania to podstawa diagnostyki.

---

## 1. Log błędów (ERRORLOG)
- 📂 Lokalizacja: `...\MSSQL\Log\ERRORLOG`, kolejne pliki: `ERRORLOG.1`, `ERRORLOG.2`, …  
- 📝 Zawartość:
  - start/stop instancji,
  - informacje o bazach danych, checkpointach, recovery,
  - błędy krytyczne, ostrzeżenia, komunikaty DBCC, dumpy,
  - backupy i restore.  
- 📌 Dostęp:
  ```sql
  EXEC sys.xp_readerrorlog 0, 1;
  ```

---

## 2. Log agenta (SQL Agent Error Log)
- 📂 Lokalizacja: `...\MSSQL\Log\SQLAGENT.OUT`, kolejne: `.1`, `.2`, …  
- 📝 Zawartość:
  - start/stop agenta,
  - status jobów,
  - błędy związane z harmonogramami, operatorami, alertami.  

---

## 3. Logi jobów SQL Agent
- 📂 Domyślnie w `...\MSSQL\Log\` lub wewnętrznie w msdb.  
- 📝 Zawartość:
  - szczegółowe wyniki poszczególnych kroków joba,
  - sukces/porażka,
  - treść błędu.  
- 📌 Dostęp: w SSMS → SQL Agent → Jobs → View History.

---

## 4. Log transakcyjny (Transaction Log)
- 📂 Lokalizacja: dla każdej bazy osobny `.ldf` (np. `master.ldf`, `YourDB_log.ldf`).  
- 📝 Zawartość:
  - wszystkie operacje modyfikujące dane (do momentu checkpointa),
  - zapewnia trwałość i spójność (ACID).  
- 📌 Dostęp:
  ```sql
  DBCC LOG (YourDB, 1);
  ```

---

## 5. Logi backupów i restore
- 📂 Wpisy trafiają do bazy **msdb** (`dbo.backupset`, `dbo.restorehistory`).  
- 📝 Zawartość:
  - kiedy i jaki backup wykonano,
  - kto wykonał operację,
  - lokalizacja pliku.  

---

## 6. Logi replikacji (Replication Log)
- 📂 Katalog: `...\MSSQL\ReplData\` + tabele w bazie **distribution**.  
- 📝 Zawartość:
  - stan agentów replikacji,
  - błędy przesyłania snapshotów,
  - historię synchronizacji.

---

## 7. Logi Always On / Availability Groups
- 📂 ERRORLOG + **Windows Event Log** (Application/System).  
- 📝 Zawartość:
  - failover, synchronizacja replik,
  - zmiany ról Primary/Secondary.  

---

## 8. Logi Database Mail
- 📂 W msdb: `dbo.sysmail_event_log`, `dbo.sysmail_faileditems`.  
- 📝 Zawartość:
  - błędy wysyłki,
  - status kolejki maili.

---

## 9. Logi integracji / SSIS / SSRS / SSAS
- **SSIS** → logi przez `dtexec` lub providery (plik, SQL, Event Log).  
- **SSRS** → `C:\Program Files\Microsoft SQL Server Reporting Services\SSRS\LogFiles\`.  
- **SSAS** → `...\OLAP\Log\`.  

---

## 10. Extended Events i Trace
- 📂 Katalog: `...\MSSQL\Log\` (pliki `.xel`).  
- 📝 Domyślna sesja: `system_health.xel`.  

---

## 11. Windows Event Logs
- **Application Log** – błędy i ostrzeżenia SQL Server.  
- **System Log** – awarie usług, start/stop SQL Server/Agent.  

---

## 12. Logi instalacji i aktualizacji (SQL Server Setup Bootstrap)

Katalog:  
```
C:\Program Files\Microsoft SQL Server\160\Setup Bootstrap\Log\
```

### a) Logi instalacji
- Tworzone przy **pierwszej instalacji instancji**.  
- Struktura:
  - `Summary.txt` – zbiorcze podsumowanie instalacji.  
  - `Detail.txt` – szczegółowe kroki instalatora.  
  - Podfoldery nazwane datą/godz. (`20250916_123456`) – logi każdego komponentu.  

### b) Logi aktualizacji CU/SP
- Tworzone przy **nakładaniu patchy**.  
- Struktura identyczna: folder z datą + `Summary.txt`, `Detail.txt`.  
- Ważne logi MSI: `sql_engine_core_inst.msi.log`, `sql_fulltext.msi.log`.  

---

## 13. Logi Filestream
- 📂 Katalog FILESTREAM.  
- 📝 Zawiera `filestream.hdr` i wewnętrzne logi transakcji FILESTREAM.  

---

## 14. Logi Full-Text Search
- 📂 `...\MSSQL\Log\fdlauncher.log`, `fdhost.log`.  

---

## 15. Logi PolyBase
- 📂 `C:\Program Files\Microsoft SQL Server\MSSQL16.<Instance>\PolyBase\Log\`.  

---

## 16. Logi Replication Agents (pliki)
- 📂 Lokalizacja konfigurowana w parametrach agenta (`-Output`).  
- Typowe: `logread.log`, `distribution.log`, `merge.log`.  

---

## 17. Logi SQL Audit
- 📂 Pliki `.sqlaudit` (ścieżka wg konfiguracji) lub Windows Event Log.  

---

## 18. Logi Windows Failover Cluster
- 📂 Generowane przez polecenie:
  ```powershell
  cluster log /g
  ```

---

# 🔎 Podsumowanie

| Log                         | Lokalizacja / Źródło                              | Co zawiera                                      |
|-----------------------------|---------------------------------------------------|-------------------------------------------------|
| **ERRORLOG**                | `...\MSSQL\Log\ERRORLOG`                      | start/stop, błędy, backupy                      |
| **SQLAGENT.OUT**            | `...\MSSQL\Log\`                              | logi SQL Agenta                                 |
| **Job logs**                | msdb / pliki                                     | wyniki kroków jobów                             |
| **Transaction log**         | `.ldf` każdej DB                                 | operacje DML, rollback                          |
| **Backup/restore**          | msdb (`backupset`, `restorehistory`)             | historia backupów/restore                       |
| **Replication**             | `ReplData` + baza `distribution`                 | stan agentów replikacji                         |
| **Always On**               | ERRORLOG + Windows Event Log                     | failovery, zmiany replik                        |
| **Database Mail**           | msdb (`sysmail_*`)                               | status i błędy maili                            |
| **SSIS/SSRS/SSAS**          | odpowiednie katalogi komponentów                 | logi ETL/raporty/analizy                        |
| **Extended Events**         | `...\MSSQL\Log\*.xel`                         | zdarzenia diagnostyczne                         |
| **Windows Event Log**       | Application/System                               | błędy usług SQL                                 |
| **Setup Bootstrap – Install**| `...\Setup Bootstrap\Log\<data>`              | logi instalacji                                 |
| **Setup Bootstrap – CU/SP** | `...\Setup Bootstrap\Log\<data>`              | logi aktualizacji CU/SP                         |
| **Filestream**              | katalog FILESTREAM                               | log FILESTREAM                                  |
| **Full-Text**               | `fdlauncher.log`, `fdhost.log`                   | logi Full-Text Search                           |
| **PolyBase**                | `PolyBase\Log`                                  | logi konektorów PolyBase                        |
| **Replication Agent logs**  | pliki `.log`                                     | szczegółowe logi agentów replikacji             |
| **SQL Audit**               | pliki `.sqlaudit` / Event Log                    | audyt logowań i działań                         |
| **Cluster Log**             | generowany `cluster log /g`                      | diagnostyka FCI/AG                              |

---

_ostatnia aktualizacja: 2025-09-16_
