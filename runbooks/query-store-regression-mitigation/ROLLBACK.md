# Query Store Regression Mitigation — ROLLBACK

## Kiedy
- forced plan szkodzi innym parametrom
- force failure
- metryki pogarszają się

## Procedura
1. Wykonaj sys.sp_query_store_unforce_plan.
2. Usuń Query Store Hint, jeśli był użyty.
3. Ponownie zmierz workload.

## Walidacja rollback
- brak niepożądanego forcingu/hintu
- zapytanie stabilne
- metryki zapisane
