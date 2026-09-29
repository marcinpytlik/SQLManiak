# Query Store Regression Mitigation — RUNBOOK

## 1. Wybierz known-good plan

Porównaj runtime stats i execution plans.

## 2. Wymuś plan

Użyj sys.sp_query_store_force_plan po zatwierdzeniu.

## 3. Sprawdź status

Zweryfikuj is_forced_plan i force_failure_count.

## 4. Obserwuj workload

Porównaj duration, CPU, reads, waits i app latency.

## 5. RCA

Sprawdź statistics, parameter sensitivity, compatibility i indexing.

Po wykonaniu przejdź do [VALIDATION.md](VALIDATION.md).
