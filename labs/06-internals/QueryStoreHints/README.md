# Query Store Hints – inteligentne poprawki bez zmian w kodzie (SQL Server 2022)

Ten mini-repozytorium to praktyczny zestaw dla DBA: jak **stabilizować plany i granty pamięci**
za pomocą **Query Store Hints** – bez dotykania kodu aplikacji.

## Co tu znajdziesz
- `docs/QueryStoreHints_Overview.md` – wprowadzenie, kiedy czego używać.
- `docs/Playbook.md` – playbook krok-po-kroku (od identyfikacji do rollbacku).
- `scripts/*.sql` – gotowe skrypty: znajdź query_id, ustaw/usuń hinty, raportuj, kandydaci do MAX_GRANT.

## Wymagania
- SQL Server 2022 (Query Store Hints).
- Query Store w bazie: `READ_WRITE` i **capture = ALL/AUTO** (nie OFF).
- Uprawnienia: zwykle `ALTER ANY DATABASE` + `ALTER` na Query Store; praktycznie: `db_owner` lub `sysadmin`.

## Typowe scenariusze
- Zapytania z **za dużymi grantami** pamięci → `OPTION (MAX_GRANT_PERCENT = X)`
- **Spille do tempdb** (zbyt małe granty) → `MIN_GRANT_PERCENT = Y`
- **Wrażliwość na parametry** → `USE HINT('DISABLE_PARAMETER_SNIFFING')`
- Test zgodności zachowania optymalizatora → `QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_150`

## Szybki start
1. Uruchom `scripts/QSH_Find_Query_ByText.sql` i skopiuj `query_id`.
2. Zastosuj wskazówkę, np. `scripts/QSH_Set_Hint_MAX_GRANT.sql` (wpisz `@query_id` i procent).
3. Zweryfikuj `scripts/QSH_Report_Hints.sql`.
4. Cofnij, kiedy gotowe: `scripts/QSH_Remove_Hints_ForQuery.sql`.

## Bezpieczeństwo
- Najpierw **obserwuj** (Query Store / Live DMVs), potem nakładaj hints.
- Zawsze miej **plan wycofania**: skrypt `Remove_*` i timestamp kto/po co.
