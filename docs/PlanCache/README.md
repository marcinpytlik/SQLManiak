# Plan cache pod lupą (SQL Server 2022)

Ten pakiet zawiera gotowe skrypty i materiał do analizy **plan cache** w SQL Server 2022.
Zakres: szybka diagnoza, statystyki, wykrywanie duplikatów planów oraz bezpieczne czyszczenie wybranych planów.

## Pliki
- `docs/PlanCache_Overview.md` – wpis/artykuł .
- `scripts/Get-PlanCache-Top10.sql` – top 10 planów wg użycia i rozmiaru.
- `scripts/Get-PlanCache-Stats.sql` – statystyki plan cache wg typu (`objtype`) i licznika użyć.
- `scripts/Detect-PlanCache-Duplicates.sql` – wykrywanie duplikatów (po `query_hash`) i „śmieci” ad‑hoc.
- `scripts/Clear-PlanCache-Safely.sql` – czyszczenie pojedynczego planu (po `plan_handle` lub `query_hash`).

## Minimalne wymogi
- SQL Server 2016+ (polecane 2022),
- uprawnienia do widoków dynamicznych (VIEW SERVER STATE).

## Ostrzeżenie
**Nie** używaj `DBCC FREEPROCCACHE` globalnie na produkcji bez planu – spowoduje to skok CPU i latencje.
W tym repo przedstawiam *precyzyjne* czyszczenie.
