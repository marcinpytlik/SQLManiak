# SQL Server Errors – Wersja operacyjna (On‑Call)

Ten folder to **szybka pomoc** podczas incydentu. Najpierw 60‑sekundowy triage, potem drzewko decyzji i gotowe komendy.

## Spis treści
- [60 sekund – triage](#60-sekund--triage)
- [Drzewko decyzji](#drzewko-decyzji)
- [Komendy „od ręki”](#komendy-od-ręki)
- [Najczęstsze błędy (cheat sheet)](#najczęstsze-błędy-cheat-sheet)
- [Wersja rozszerzona – przykłady i checklisty](#wersja-rozszerzona--przykłady-i-checklisty)

---

## 60 sekund – triage

1. **Czy instancja żyje?**
   ```powershell
   Get-Service MSSQL* | Select Name, Status
   ```
2. **Czy port nasłuchuje?**
   ```powershell
   Test-NetConnection -ComputerName <SERVER> -Port 1433
   ```
3. **Czy DNS/ścieżka jest poprawna?**
   ```powershell
   nslookup <SERVER>
   ```
4. **Czy to błąd logowania (18456)?** → sprawdź `State` w ERRORLOG.  
   ```sql
   EXEC xp_readerrorlog 0, 1, 'Error: 18456';
   ```
5. **Czy brakuje miejsca / log pełny (9002)?**
   ```sql
   SELECT name, log_reuse_wait_desc FROM sys.databases;
   ```
6. **Czy storage/I/O krzyczy (823/824/825)?** → szybki CHECKDB na małym zakresie lub `Event Viewer`.

> Jeśli 1–2 padają → **sieć/instancja** (Error 17/53/258).  
> Jeśli 4–5 wskazują problemy → **logowanie/baza/miejsce**.  
> Jeśli 6 → **storage** – eskaluj do zespołu storage natychmiast.

---

## Drzewko decyzji

```
               Brak połączenia?
                     |
             +-------+--------+
             |                |
            TAK              NIE
             |                |
   [A] Sieć/Instancja   Błąd po zalogowaniu?
             |                |
   - Service running?         +---------+
   - Port 1433 otwarty?                 |
   - DNS/FQDN ok?                       TAK
   - SQL Browser?                        |
             |                 [B] Login/DB/Uprawnienia
             |                 - 18456 → state
             |                 - 4060  → status DB
             |                 - default DB istnieje?
             |
   I/O/Storage alerty?                         |
             |                                 NIE
            TAK                                 |
             |                        [C] Wydajność / Miejsce
   [D] Storage/Corruption             - log pełny 9002? backup loga
   - 823/824/825 w ERRORLOG           - 1101/1105 → powiększ pliki
   - CHECKDB                          - tempdb 3958 → dodaj pliki
   - Event Viewer                     - deadlock 1205 → retry + tuning
```

---

## Komendy „od ręki”

**Port i protokoły**
```sql
SELECT local_tcp_port
FROM sys.dm_exec_connections
WHERE session_id = @@SPID;
```

**ERRORLOG (ostatnie wpisy)**
```sql
EXEC xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc';
```

**Status baz i reuse loga**
```sql
SELECT name, state_desc, recovery_model_desc, log_reuse_wait_desc
FROM sys.databases;
```

**Kto kogo blokuje**
```sql
SELECT r.session_id, r.blocking_session_id, r.wait_type, r.command, DB_NAME(r.database_id) db
FROM sys.dm_exec_requests r
WHERE r.blocking_session_id <> 0;
```

**Deadlock XE (szybki start)**
```sql
IF NOT EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = 'deadlocks')
BEGIN
  CREATE EVENT SESSION deadlocks ON SERVER
  ADD EVENT sqlserver.lock_deadlock
  ADD TARGET package0.event_file(SET filename='C:\XE\deadlocks.xel')
  WITH (STARTUP_STATE=ON);
END;
ALTER EVENT SESSION deadlocks ON SERVER STATE = START;
```

---

## Najczęstsze błędy (cheat sheet)
Zobacz: **SQL_Errors_CheatSheet.md** (tabelka: Error → Znaczenie → Fix).

## Wersja rozszerzona – przykłady i checklisty
Zobacz: **SQL_Errors_Extended.md** (pełne opisy, ERRORLOG, checklisty).
