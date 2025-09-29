# SQL Server – Najczęstsze błędy natywne (wersja rozszerzona)

Poniżej znajdziesz praktyczne opisy, przykładowe komunikaty z ERRORLOG, szybkie checklisty diagnostyczne oraz polecenia T‑SQL/PowerShell do weryfikacji.

---

## 17 – SQL Server does not exist or access denied

**Znaczenie:** klient nie może nawiązać połączenia z instancją (warstwa sieć/instancja).

**Przykładowe komunikaty (klient/ERRORLOG):**
- *[Microsoft][ODBC Driver] SQL Server does not exist or access denied.*
- ERRORLOG zwykle **nie** zawiera wpisu o próbie logowania, bo połączenie nie doszło do serwera.

**Diagnoza – checklist:**
1. Usługa SQL: `Get-Service MSSQL*`
2. Port: stały 1433 lub inny? (Configuration Manager / `sys.dm_exec_connections`)
3. Firewall: inbound TCP 1433 (i UDP 1434 dla Browser).
4. DNS/FQDN: `ping`, `nslookup`, użyj `tcp:server,port`.
5. SQL Browser dla instancji nazwanych.

**Szybkie komendy:**
```powershell
Get-Service -Name MSSQL* | Select Name,Status
Test-NetConnection -ComputerName <SERVER> -Port 1433
```
```sql
SELECT local_tcp_port
FROM sys.dm_exec_connections
WHERE session_id = @@SPID;
```

---

## 53 – Named Pipes Provider, SQL Server not found

**Znaczenie:** j.w., ale przez Named Pipes.

**Tip:** wymuś TCP/IP: `tcp:servername,1433` albo w łańcuchu połączenia `Network Library=DBMSSOCN`.

---

## 258 – Connection timeout

**Znaczenie:** klient nie zdążył zestawić połączenia w czasie limitu.

**Checklist:** trasa sieciowa, firewall, przeciążenie serwera (accept backlog), proxy/VPN.

---

## 18456 – Login failed for user '<login>'

**Znaczenie:** uwierzytelnienie nieudane. Kluczowy jest **State** w ERRORLOG.

**Przykładowe ERRORLOG:**
```
Error: 18456, Severity: 14, State: 8.
Login failed for user 'app_user'. Reason: Password did not match...
```
**Najczęstsze State:**  
- 2/5 – invalid user / user not associated  
- 7 – login disabled  
- 8 – wrong password  
- 11/12 – login valid, ale brak dostępu do serwera  
- 38 – cannot open default database  
- 58 – login mismatch z trybem auth (np. Windows vs SQL)

**Diagnoza – checklist:**
1. Sprawdź tryb autoryzacji (Mixed?): `SELECT SERVERPROPERTY('IsIntegratedSecurityOnly');`
2. Status logina: `SELECT is_disabled FROM sys.server_principals WHERE name = 'user';`
3. Domyślna baza logina istnieje/ONLINE?
4. Czy użytkownik ma prawo CONNECT SQL?

**Przydatne T‑SQL:**
```sql
-- Tryb autoryzacji (0 = Mixed, 1 = tylko Windows)
SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') AS WindowsOnly;

-- Status logina
SELECT name, is_disabled FROM sys.server_principals WHERE type_desc = 'SQL_LOGIN';

-- Domyślna baza logina
SELECT sp.name, sp.default_database_name
FROM sys.server_principals sp
WHERE sp.type_desc = 'SQL_LOGIN';
```

---

## 4060 – Cannot open database requested by the login

**Znaczenie:** zalogowano się do serwera, ale nie można otworzyć wskazanej bazy.

**Typowe powody:** baza OFFLINE/RESTORING/SUSPECT, brak uprawnień.

**Szybka diagnoza:**
```sql
SELECT name, state_desc FROM sys.databases WHERE name = N'<DB>';
```

**Napraw:** nadaj uprawnienia, ONLINE bazę, napraw spójność (`DBCC CHECKDB`/restore).

---

## 823 – I/O error (hardware device)

**Znaczenie:** błąd fizycznego I/O (odczyt/zapis nieudany).

**Przykład ERRORLOG:**
```
Error: 823, Severity: 24, State: 2.
I/O error (bad page ID / cyclic redundancy check) detected during read at offset...
```

**Checklist:**
- System Event Log (disk, storport, HBA).
- `DBCC CHECKDB` – zidentyfikuj uszkodzenia.
- Weryfikuj ścieżkę storage (SAN, driver, firmware).

**T‑SQL:**
```sql
DBCC CHECKDB (N'<DB>') WITH NO_INFOMSGS, ALL_ERRORMSGS;
```

---

## 824 – Logical consistency-based I/O error

**Znaczenie:** uszkodzenie logiczne (checksum/torn page).

**ERRORLOG:**
```
Error: 824, Severity: 24, State: 2.
SQL Server detected a logical consistency-based I/O error...
```

**Działania:** `DBCC CHECKDB`, analiza typu błędu, zwykle **restore** z poprawnego backupu.

---

## 825 – Read retry required

**Znaczenie:** ostrzeżenie – SQL musiał ponowić odczyt. Często prekursor poważniejszych awarii storage.

**Działania:** monitoruj, sprawdź ścieżkę I/O, HBA, kable, firmware.

---

## 1101 / 1105 – Could not allocate space

**Znaczenie:** brak miejsca w bazie/plikach/na dysku.

**Diagnoza:**
```sql
SELECT name, size*8/1024 AS SizeMB, max_size
FROM sys.database_files;
```

**Napraw:** zwiększ pliki, dodaj pliki, włącz autogrow w **MB** (nie %), zwolnij miejsce na dysku.

---

## 5120 – Unable to open the physical file

**Znaczenie:** SQL nie może otworzyć pliku MDF/NDF/LDF (ścieżka/ACL/storage).

**Checklist:** istnienie ścieżki, prawa NTFS dla konta usługi, dostępność voluminów (CSV/SAN).

---

## 3958 – TempDB is full

**Znaczenie:** operacja wymaga miejsca w tempdb.

**Szybkie kroki:**
- Dodaj pliki `tempdb` i/lub zwiększ rozmiary (równe, autogrow w MB).
- Zweryfikuj zapytania zużywające version store/worktables.

**T‑SQL:**
```sql
SELECT * FROM sys.dm_db_file_space_usage; -- zajętość tempdb
```

---

## 1205 – Deadlock victim

**Znaczenie:** twoja transakcja została wybrana jako ofiara.

**Diagnostyka:**
- Włącz Graph deadlock w XE/Trace.
- Zastosuj retry logic w aplikacji.

**T‑SQL (XE – definicja przykładowa):**
```sql
CREATE EVENT SESSION [deadlocks] ON SERVER
ADD EVENT sqlserver.lock_deadlock
ADD TARGET package0.event_file(SET filename = 'C:\XE\deadlocks.xel')
WITH (STARTUP_STATE=ON);
ALTER EVENT SESSION [deadlocks] ON SERVER STATE = START;
```

---

## 3960 – Snapshot isolation transaction aborted

**Znaczenie:** konflikt wersji przy SI/RCSI.

**Działania:** ponów transakcję, przeanalizuj konfliktujące operacje (blokady/wersje).

---

## 9002 – The transaction log is full

**Znaczenie:** log pełny.

**Diagnoza:**
```sql
SELECT name, log_reuse_wait_desc FROM sys.databases;
```

**Napraw:**
- Model FULL: zrób **backup loga**, rozważ powiększenie pliku.
- Zidentyfikuj długie transakcje/XEvent log_growth.

---

## 3013 – BACKUP/RESTORE error (ogólny)

**Znaczenie:** błąd operacji – patrz poprzedzające kody (np. 3201/3313).

---

## 3201 – Cannot open backup device

**Znaczenie:** brak dostępu do ścieżki backupu/udostępnienia.

**Checklist:** ścieżka istnieje, ACL dla konta usługi SQL, uprawnienia do udziału sieciowego.

---

## 3313 – Error during redo/undo (restore)

**Znaczenie:** problem podczas recovery po restore (ciągłość backupów, uszkodzenie loga).

**Działania:** zweryfikuj łańcuch FULL/DIFF/LOG, integralność backupów, `RESTORE VERIFYONLY`.

---

# Załączniki: uniwersalne snippety

## Sprawdzenie portów i protokołów
- SQL Server Configuration Manager → **Protocols for <Instance>** (TCP/IP enabled).
- Stały port: zakładka **IP Addresses** → IPAll → **TCP Port**.

## Odczyt ERRORLOG (ostatnia rotacja)
```sql
EXEC xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc';
```

## Szybki health-check bazy
```sql
SELECT name, state_desc, recovery_model_desc, log_reuse_wait_desc
FROM sys.databases;
```

## Kto mnie blokuje? (przy błędach transakcyjnych)
```sql
SELECT 
  r.session_id, r.blocking_session_id, r.status, r.wait_type, r.wait_time, r.command,
  db_name(r.database_id) AS dbname, t.text
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;
```

---

# TL;DR
- **Połączenia**: 17/53/258 → usługa/port/firewall/DNS.  
- **Logowanie**: 18456 (patrz **State** w ERRORLOG).  
- **Storage**: 823/824/825/5120 → CHECKDB + sprzęt/storage.  
- **Miejsce**: 1101/1105/3958/9002 → pre-size, autogrow w MB, monitoring.  
- **Transakcje**: 1205/3960 → retry i porządek blokad.  
- **Backup/Restore**: 3013/3201/3313 → ścieżki, uprawnienia, łańcuch backupów.
