
Nie każdy plan zasługuje, żeby zostać w pamięci. SQL Server jest jak bibliotekarz – kataloguje plany,
trzyma je w cache, a gdy pamięć się kończy… wyrzuca te najmniej używane.

## Czym jest plan cache?
To część pamięci przeznaczona na **skompilowane plany zapytań** (compiled plans). Dzięki niej kolejne wykonania
tego samego zapytania nie wymagają ponownej kompilacji.

**Główne korzyści:**
- mniej kompilacji (mniejsze CPU),
- stabilniejsza wydajność,
- możliwość inspekcji tego, co naprawdę się dzieje.

## Co warto monitorować
- które plany są najczęściej używane (usecounts),
- ile pamięci zajmują (size_in_bytes),
- udział ad‑hoc query plans vs. procedur,
- duplikaty planów (różny tekst / ta sama logika – *query_hash*),
- regresje planu (plan zmienia się dla tych samych zapytań).

## Przydatne DMV/DMB
- **sys.dm_exec_cached_plans** – metadane planów w cache,
- **sys.dm_exec_sql_text(plan_handle)** – tekst T‑SQL,
- **sys.dm_exec_query_plan(plan_handle)** – XML planu,
- **sys.dm_exec_query_stats** – statystyki wykonania (execution_count, last_elapsed_time, *query_hash*).

## Uwaga na ślepe czyszczenie cache
`DBCC FREEPROCCACHE` zdejmuje wszystkie plany. To jak restart mózgu podczas egzaminu.
Zamiast tego **usuwaj precyzyjnie** – po *plan_handle* lub *query_hash* (patrz: skrypt `Clear-PlanCache-Safely.sql`).

## SQL Server 2022 – co pomaga?
- **Parameterized Plan Optimization (PPO)** – lepsze dopasowanie planu do wartości parametrów,
- ulepszenia w CE/feedback (Cardinality Estimation i feedback zapytań),
- *Query Store Hints* – możliwość wymuszenia wskazówek dla konkretnych zapytań bez zmiany kodu.

## Jak korzystać z repo
1. Uruchom skrypty z folderu `scripts/` na środowisku testowym.
2. Zidentyfikuj duplikaty i „śmieci” w cache (`Detect-PlanCache-Duplicates.sql`).
3. Jeśli to bezpieczne – usuń wybrane plany (`Clear-PlanCache-Safely.sql`).
4. Wprowadź poprawki w parametryzacji / wzorcach zapytań (procedury, sp_executesql).

> „Nie każdy plan wart jest drugiego podejścia – ale każdy błąd w planie wart jest zrozumienia.”


