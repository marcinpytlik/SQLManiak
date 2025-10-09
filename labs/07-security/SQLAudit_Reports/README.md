# 📦 SQL Server Audit – raporty i agregaty (repo‑ready)

Ten pakiet pozwala czytać **pliki SQL Server Audit** (`*.sqlaudit`) bezpośrednio z serwera
i generować sensowne zestawienia: per użytkownik, per operacja, per obiekt,
z „kombajnem” na `GROUPING SETS`, heatmapą godzinową oraz tabelą dziennych agregatów.

> **Założenia**
> - Masz już skonfigurowany i uruchomiony **SQL Server Audit** (poziom serwera/bazy),
>   zapisujący zdarzenia do **pliku**.
> - Pakiet _nie tworzy_ audytu — tylko **czyta** istniejące pliki przez
>   `sys.fn_get_audit_file`.

## Struktura

```
sql/
  00_discover_audits.sql          # pomoc: sprawdzenie nazw audytów i ścieżek
  10_ufn_AuditEvents.sql          # TVF: ufn_AuditEvents(@AuditName, @FromDate, @ToDate)
  20_reports.sql                  # gotowe raporty/„kombajn” oparte o TVF
  30_agg_table_and_proc.sql       # tabela dziennych agregatów + proc. odświeżająca
  40_agent_job.sql                # przykładowy job SQL Agenta (nocne ładowanie)
  99_cleanup.sql                  # sprzątanie: drop function/table/proc/job (opcjonalnie)
README.md
```

## Szybki start

1. **Sprawdź nazwę audytu** i aktualną ścieżkę plików:
   ```sql
   :r sql/00_discover_audits.sql
   ```

2. **Utwórz funkcję TVF** i obiekty raportowe (uruchamiaj po kolei):
   ```sql
   :r sql/10_ufn_AuditEvents.sql
   :r sql/30_agg_table_and_proc.sql
   ```

3. **Odpal raporty ad‑hoc** (okno ostatnich 7–14 dni):
   ```sql
   :r sql/20_reports.sql
   ```

4. (Opcjonalnie) **Zainstaluj job** SQL Agenta do nocowego ładowania agregatów:
   ```sql
   :r sql/40_agent_job.sql
   ```

> Jeśli używasz SSMS bez trybu `:r`, po prostu otwieraj i uruchamiaj pliki po kolei.

## Parametry i strefa czasu

- Wszystkie zapytania przyjmują **@AuditName** (np. `DBAudit`) i okno czasu.
- `event_time` w pliku audytu jest w **UTC**. Funkcja TVF zwraca zarówno
  `event_time_utc`, jak i `event_time_local` przeliczone przez `SWITCHOFFSET`
  na strefę serwera (u Ciebie: **Europe/Warsaw**).

## Co dostajesz

- „Kombajn” z `GROUPING SETS` (jedno zapytanie → wiele poziomów agregacji).
- Top obiekty per operacja (SELECT/INSERT/UPDATE/DELETE/EXECUTE/REFERENCES).
- Aktywność per użytkownik i per godzina (heatmapa).
- Tabela **AuditDailyAgg** + procedura **Refresh_AuditDailyAgg**,
  żeby raporty działały błyskawicznie.
- Przykładowy **SQL Agent Job** ładujący dziennie zakres poprzedniej doby.

## Weryfikacja działania

- Po uruchomieniu `20_reports.sql` powinieneś zobaczyć wyniki w kilku sekcjach.
- Jeśli nic nie zwraca:
  - sprawdź, czy audyt **działa** i ma jakieś wpisy w ostatnich dniach,
  - upewnij się, że nazwa w `@AuditName` trafia w uruchomiony audyt,
  - sprawdź uprawnienia do odczytu plików `.sqlaudit` przez usługę SQL Server.

## Uwaga dot. bezpieczeństwa

Pliki audytu mogą zawierać fragmenty zapytań (`statement`). Traktuj je jak **dane wrażliwe**.
Rozsądnie ograniczaj uprawnienia do wykonywania raportów i do tabeli agregatów.

---


