# 🧪 SQL Server 2022 – Weryfikacja SPN i Kerberos

## 1. Sprawdzenie trybu uwierzytelniania bieżącego połączenia
```sql
SELECT 
    s.session_id,
    c.auth_scheme,
    c.net_transport,
    c.encrypt_option,
    s.login_name,
    c.client_net_address
FROM sys.dm_exec_sessions s
JOIN sys.dm_exec_connections c ON s.session_id = c.session_id
WHERE s.session_id = @@SPID;
```
👉 `auth_scheme` pokaże **KERBEROS** albo **NTLM**.

---

## 2. Lista wszystkich aktywnych połączeń i schematów autoryzacji
```sql
SELECT 
    c.session_id,
    c.auth_scheme,
    c.net_transport,
    c.client_net_address,
    s.login_name,
    s.host_name,
    s.program_name
FROM sys.dm_exec_connections c
JOIN sys.dm_exec_sessions s ON c.session_id = s.session_id
ORDER BY c.session_id;
```

---

## 3. Diagnostyka SPN – nieudane logowania Kerberos
Sprawdź w Error Log:
```sql
EXEC xp_readerrorlog 0, 1, 'Cannot generate SSPI context';
```

---

## 4. Kontrola aktualnych SPN w systemie
Na kontrolerze domeny (PowerShell):
```powershell
setspn -L SQLMANAIK\gmsa-sql2022$
```

---

## 5. Dobre praktyki
- Jeśli `auth_scheme = NTLM`, a oczekujesz Kerberosa → sprawdź SPN.  
- Testuj logowanie z klienta przez **FQDN** i port, np.:  
  ```
  sqlcmd -S sqlsrv01.contoso.com,1433 -E
  ```
