# SQLSTATE ↔ Msg ↔ Znaczenie ↔ Fix (ściąga DBA)

> Szybka ściąga dla typowych kombinacji komunikatów w logach SQL Server Agent.
> **SQLSTATE** pochodzi z warstwy ODBC, **Msg** to numer błędu SQL Server.

---

## 1. Najczęściej spotykane pary

| SQLSTATE | Msg   | Znaczenie (opis) | Typowe fixy |
|----------|-------|------------------|-------------|
| **01000** | **15638** | Domyślna baza loginu jest niedostępna (usunięta/offline/brak uprawnień) | `ALTER LOGIN ... WITH DEFAULT_DATABASE = master;` albo przywróć/uprawnij bazę |
| **01000** | **229**   | Permission denied (SELECT/EXECUTE/INSERT/UPDATE) | `GRANT EXECUTE/SELECT...` na obiekt; upewnij się co do schematu i ownership chaining |
| **01000** | **2812**  | Could not find stored procedure | Dodaj `USE [baza];` i kwalifikuj `EXEC schema.proc` |
| **01000** | **102 / 207** | Syntax error / Invalid column | Literówka, brak kolumny, niepoprawny batch |
| **01000** | **8115** | Arithmetic overflow | Zmień typ kolumny/skalę, waliduj dane |
| **01000** | **8152** | String or binary data would be truncated | Rozszerz definicję kolumny lub kontroluj skracanie |
| **08001 / 08004** | brak Msg | Connection failed | Sprawdź instancję, port/TCP, firewall, aliasy, SPN/Kerberos |
| **28000** | **18456** | Login failed | Popraw hasło, tryb mixed, sprawdź `STATE` w errorlog |
| **42000** | **15151** | Cannot find the object / permission denied | Użyj poprawnej nazwy obiektu i nadaj prawa DDL |
| **42000** | **2627 / 2601** | Naruszenie PK/Unique | Deduplikuj dane, użyj UPSERT (MERGE/ON DUPLICATE) |
| **42S02** | brak Msg | Base table or view not found | Zła baza/schemat, brak obiektu |

---

## 2. Jak czytać komunikaty w logu joba

Przykład z historii joba:
```
Executed as user: sa. 
The database specified as the default for this login is unavailable. 
[SQLSTATE 01000] (Message 15638).  The step failed.
```

- **SQLSTATE 01000** → „opakowanie” (general warning), mało mówi.  
- **Msg 15638** → prawdziwy błąd: default DB niedostępna.  
- **Fix** → zmień default DB loginu na `master`.

---

## 3. Pro tipy

- SQLSTATE 01000 prawie zawsze = „szukaj właściwego Msg poniżej”.  
- Najpierw rozpoznaj **Msg**, dopiero potem patrz na SQLSTATE.  
- Własne błędy (`RAISERROR`/`THROW`) wychodzą jako `Msg 50000` + `SQLSTATE 01000`.  
- W kroku joba **używaj jawnego `USE [baza]` i `schema.proc`**, żeby uniknąć 4060/2812.  

---

## 4. Snippety do szybkiej diagnostyki

**Ostatni komunikat z joba**
```sql
USE msdb;
SELECT TOP (1)
  j.name AS job_name, h.step_id, h.step_name,
  h.run_date, h.run_time, h.sql_severity, h.message
FROM dbo.sysjobhistory h
JOIN dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name = N'NazwaTwojegoJoba'
ORDER BY h.instance_id DESC;
```

**Default database fix (15638)**
```sql
ALTER LOGIN [DOMAIN\Login] WITH DEFAULT_DATABASE = [master];
```

**Minimalne EXECUTE do procedury**
```sql
GRANT EXECUTE ON OBJECT::dbo.TwojaProcedura TO [DOMAIN\Login];
```

---

