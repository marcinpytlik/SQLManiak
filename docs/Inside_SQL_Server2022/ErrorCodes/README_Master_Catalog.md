# Katalog błędów dla SQL Server Agent – SQLSTATE ↔ Msg (wersja rozszerzona)

Ta ściąga obejmuje **praktycznie wszystkie** kody SQLSTATE, które realnie pojawiają się w logach SQL Server/ODBC, oraz **najczęściej spotykane** błędy **Msg** z silnika SQL Server, zgrupowane pod kątem jobów w Agencie.

> Uwaga: SQLSTATE to kody warstwy klient/ODBC. Kluczem diagnostycznym jest **Msg** – to on zwykle wskazuje źródło problemu.  
> Dla rzadkich Msg użyj dołączonych skryptów, aby odpytać `sys.messages` i uzyskać opis z instancji.

---

## Jak czytać kombinacje

Przykład z historii joba:
```
[SQLSTATE 01000] (Message 15638) The database specified as the default for this login is unavailable.
```
- `01000` = etykieta „General warning” → patrzymy na **Msg 15638**.
- Fix: `ALTER LOGIN ... WITH DEFAULT_DATABASE = master;`.

---

## Szybkie mapowanie (wybór)

### SQLSTATE → „co zwykle oznacza”
- **01000** – ogólny warning (szukaj Msg).
- **08001/08004/08006** – kłopoty z połączeniem.
- **28000** – uwierzytelnienie (często `Msg 18456`).
- **42000** – składnia/uprawnienia.
- **42S02 / S0002 / S0022** – obiekty/kolumny nie istnieją.
- **HYT00 / S1T00** – timeout.
- **HY000/HY001** – ogólne/alloc pamięci.

### Msg (wybór najczęstszych)
- **18456/4060/15638** – logowanie/default DB.
- **207/208/2812** – obiekty/kolumny/brak `schema`/`USE`.
- **229/15151** – uprawnienia/DDL.
- **245/8115/8152** – konwersje/przepełnienia/ucięcia.
- **2627/2601/547** – PK/UNIQUE/FK/Check.
- **3201/3013/3154/5120/3271** – backup/restore/IO/środowisko.
- **1205/1222** – deadlock/locki.
- **823/824/825** – I/O i integralność stron.
- **9002/1105/5184** – przestrzeń/log.

---

## Pliki CSV
- `SQLSTATE_Catalog.csv` – pełna tabela SQLSTATE (kolumny: kod, znaczenie, przyczyny, fix).
- `SQLServer_Msg_Catalog.csv` – tabela najczęstszych Msg z opisami i naprawami.

---

## Snippety: automatyczna diagnoza i opisy Msg

**1) Ostatni komunikat kroku joba**
```sql
USE msdb;
SELECT TOP (1)
  j.name AS job_name, h.step_id, h.step_name,
  h.run_status, h.sql_severity, h.message, h.run_date, h.run_time
FROM dbo.sysjobhistory h
JOIN dbo.sysjobs j ON j.job_id = h.job_id
WHERE j.name = N'NazwaTwojegoJoba'
ORDER BY h.instance_id DESC;
```

**2) Pobierz opis błędu z `sys.messages` (w tym polskie tłumaczenia, jeśli dostępne)**
```sql
DECLARE @msg INT = 15638;
SELECT TOP (10) message_id, language_id, text
FROM sys.messages
WHERE message_id = @msg
ORDER BY language_id;
```

**3) Parser: wyłuskanie SQLSTATE/Msg z historii jobów (pattern matching)**
```sql
USE msdb;
WITH H AS (
  SELECT TOP (1000) instance_id, step_id, step_name, message
  FROM dbo.sysjobhistory
  WHERE message LIKE '%SQLSTATE%' OR message LIKE '%Message %'
  ORDER BY instance_id DESC
)
SELECT
  instance_id, step_id, step_name,
  TRY_CONVERT(varchar(5), SUBSTRING(message, CHARINDEX('SQLSTATE',message)+9, 5)) AS SQLSTATE_like,
  TRY_CONVERT(int, SUBSTRING(message, CHARINDEX('Message',message)+8, 10)) AS Msg_like,
  message
FROM H;
```

**4) Wymuszenie poprawnej bazy i schematu w kroku**
```sql
USE [TwojaBaza];
GO
EXEC dbo.TwojaProcedura @param1 = ...;
```

**5) Szybkie fixy**  
- **Default DB (15638):**
```sql
ALTER LOGIN [DOMAIN\Login] WITH DEFAULT_DATABASE = [master];
```
- **Brak EXECUTE do procedury:**
```sql
GRANT EXECUTE ON OBJECT::dbo.TwojaProcedura TO [DOMAIN\Login];
```

---

