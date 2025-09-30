# 🪪 SQL Server 2022 – SPN (Service Principal Name) Checklista

## 1. Kiedy potrzebny jest SPN?
- [ ] Gdy łączysz się do instancji SQL Server po **nazwie hosta** lub FQDN (np. sqlsrv01.contoso.com).  
- [ ] Gdy używasz **Kerberos** (delegacja między warstwami: IIS → SQL).  
- [ ] Zawsze, gdy konto usługi to konto **domenowe** albo **gMSA**.  

## 2. Jak wygląda SPN dla SQL Server?
Format:  
```
MSSQLSvc/FQDN:port
MSSQLSvc/hostname:port
```

Przykład dla default instance na porcie 1433:  
```
MSSQLSvc/sqlsrv01.contoso.com:1433
MSSQLSvc/sqlsrv01:1433
```

## 3. Rejestracja SPN (przykład)
Na kontrolerze domeny (lub z uprawnieniami Domain Admin):  
```powershell
setspn -S MSSQLSvc/sqlsrv01.contoso.com:1433 CONTOSO\gmsa-sql2022$
setspn -S MSSQLSvc/sqlsrv01:1433 CONTOSO\gmsa-sql2022$
```

## 4. Weryfikacja SPN
```powershell
setspn -L CONTOSO\gmsa-sql2022$
klist
```

## 5. Dobre praktyki
- [ ] Rejestruj zawsze **hostname** i **FQDN**.  
- [ ] Nigdy nie przypisuj jednego SPN do dwóch kont → konflikt i brak Kerberosa.  
- [ ] Utrzymuj dokumentację, kto ma jakie SPN.  
- [ ] W produkcji testuj logowanie Kerberos (`auth_scheme` w DMV sys.dm_exec_connections).  
