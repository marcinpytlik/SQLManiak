# SQLAgent_CurrencyRates (NBP → SQL Server)

Zestaw produkcyjny do pobierania kursów walut z **NBP Web API** i zapisu do tabeli `dbo.ExchangeRates` w SQL Server 2022.
Realizacja dla SQL Server 2022 wykorzystuje **SQL Server Agent + PowerShell** (bez CLR, bez xp_cmdshell).

> **Uwaga:** `sp_invoke_external_rest_endpoint` **nie jest dostępny w SQL Server 2022 on‑prem**. Jeśli używasz **Azure SQL DB/MI** albo **SQL Server 2025 (preview)**, skorzystaj z alternatywnego skryptu w folderze `sql-alt/`.

---

## Struktura

- `sql/01_create_schema.sql` – tabela docelowa + indeksy.
- `sql/02_parse_and_merge_proc.sql` – procedura `dbo.usp_UpsertNbpRatesFromJson` (parser `OPENJSON` + MERGE).
- `sql/03_create_agent_job.sql` – utworzenie joba Agenta, harmonogramu i kroku PowerShell.
- `ps/FetchNbpRates.ps1` – skrypt PowerShell pobierający JSON z NBP i wywołujący procedurę.
- `sql-alt/02_proc_sp_invoke.sql` – **alternatywa** dla środowisk z `sp_invoke_external_rest_endpoint` (Azure SQL/SQL 2025).

## Wymagania

- SQL Server 2022 (Developer/Enterprise) z włączonym **SQL Server Agent**.
- Uprawnienia do tworzenia tabel, procedur i jobów (`db_ddladmin`/`db_owner` + `SQLAgentOperatorRole`).
- Dostęp HTTP/HTTPS z węzłów serwera/klastra do `https://api.nbp.pl/`.

## Instalacja (SQL 2022 + PowerShell)

1. Uruchom kolejno:
   - `sql/01_create_schema.sql`
   - `sql/02_parse_and_merge_proc.sql`
2. W pliku `ps/FetchNbpRates.ps1` ustaw parametry połączenia (instancja, baza) lub przekaż je w jobie.
3. Uruchom `sql/03_create_agent_job.sql` i podaj wartości:
   - `@InstanceName` – nazwa instancji (np. `MSSQLSERVER` lub `NODE1\SQL2022`),
   - `@DbName` – nazwa bazy docelowej.
4. Job jest planowany **codziennie o 12:15 (Europe/Warsaw)**. Zmień harmonogram wg potrzeb.

## Aktualizacja/Retry

- API NBP publikuje **jedną tabelę dziennie** dla tabeli A. Skrypt jest **idempotentny** – dla istniejących rekordów wykonuje `MERGE`, więc wielokrotne uruchomienia tego samego dnia niczego nie dublują.
- W jobie ustawiono bezpieczne retry (2 ponowienia co 5 minut) po stronie Agenta (zależnie od konfiguracji).

## Alternatywa: `sp_invoke_external_rest_endpoint` (Azure SQL / SQL Server 2025 preview)

Jeśli Twoje środowisko wspiera procedurę systemową:
- włącz funkcję (SQL 2025/MI):  
  `EXEC sp_configure 'external rest endpoint enabled', 1; RECONFIGURE;`
- nadaj uprawnienie:  
  `GRANT EXECUTE ANY EXTERNAL ENDPOINT TO <login/role>;`
- wdroż `sql-alt/02_proc_sp_invoke.sql` i utwórz job T-SQL wykonujący procedurę.

Źródła:
- Dokumentacja `sp_invoke_external_rest_endpoint` – Microsoft Learn.
- Specyfikacja NBP API: `https://api.nbp.pl/api` (tabela A: `/exchangerates/tables/A?format=json`).

## Weryfikacja

```sql
-- dzisiejsza tabela
SELECT TOP 10 *
FROM dbo.ExchangeRates
WHERE effective_date = CAST(GETDATE() AS date)
ORDER BY code;

-- ostatnie 7 publikacji dla EUR/USD
SELECT code, effective_date, rate
FROM dbo.ExchangeRates
WHERE code IN ('EUR','USD')
  AND effective_date >= DATEADD(day,-7, CAST(GETDATE() AS date))
ORDER BY code, effective_date DESC;
```

## Licencja

CC BY 4.0 – używaj śmiało z atrybucją.
