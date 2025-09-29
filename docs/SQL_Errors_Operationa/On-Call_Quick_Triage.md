# On‑Call – Quick Triage (60s)

**Cel:** zidentyfikować kategorię problemu w 60 sekund i obrać właściwą ścieżkę.

## Kroki

1) **Service**
```powershell
Get-Service MSSQL* | Select Name, Status
```
- Jeśli **Stopped** → uruchom / sprawdź Event Log.

2) **Port**
```powershell
Test-NetConnection -ComputerName <SERVER> -Port 1433
```
- Jeśli **Closed** → firewall/SQL TCP/IP/port dynamiczny.

3) **DNS/FQDN**
```powershell
nslookup <SERVER>
```
- Użyj `tcp:servername.domain.local,1433`.

4) **ERRORLOG – logowanie i I/O**
```sql
EXEC xp_readerrorlog 0,1,'Error: 18456';
EXEC xp_readerrorlog 0,1,'Error: 823';
EXEC xp_readerrorlog 0,1,'Error: 824';
EXEC xp_readerrorlog 0,1,'Error: 825';
```

5) **Miejsce / log**
```sql
SELECT name, log_reuse_wait_desc FROM sys.databases;
```

## Decyzja
- **Brak połączenia** → Error 17/53/258 → sieć/instancja.  
- **18456/4060** → uwierzytelnienie/baza.  
- **823/824/825** → storage → eskalacja.  
- **9002/1101/1105/3958** → brak miejsca/log/tempdb.
