# ADR-004: Query Store Baseline Before Compatibility-Level Change

- Status: Accepted
- Date: 2026-09-30
- Owners: SQLManiak / DBA

## Context

Zmiana compatibility level może zmienić zachowanie optymalizatora i plany wykonania. Repo posiada Query Store regression labs, QS Compat Report oraz checklistę zmiany compatibility level.

## Decision drivers

- możliwość porównania BEFORE/AFTER,
- wykrycie regresji planów,
- odwracalna mitigacja przez Force Plan/Query Store Hints,
- oddzielenie zmiany engine version od optimizer behavior.

## Considered options

### Podniesienie compatibility level bez baseline

Odrzucono jako utrudniające RCA.

### Query Store baseline przed zmianą

Przyjęto.

## Decision

Przed podniesieniem compatibility level:

1. Query Store musi zbierać reprezentatywną historię.
2. Definiujemy baseline window.
3. Rejestrujemy krytyczne query_id/plan_id.
4. Po zmianie porównujemy duration, CPU, logical reads, waits i plany.
5. Force Plan/Query Store Hint jest używany tylko jako kontrolowana mitigacja.

## Consequences

### Positive

- szybsza identyfikacja regresji,
- możliwość porównania planów,
- łatwiejszy rollback/mitigation.

### Negative / Trade-offs

- wymaga okresu obserwacji przed zmianą,
- wymaga capacity i poprawnego stanu Query Store,
- historyczny plan nie zawsze pasuje do wszystkich parametrów.

## Validation

- Query Store READ_WRITE,
- baseline przed zmianą,
- QS Compat Report,
- porównanie representative workload po zmianie.

## Revisit when

- zmienia się strategia Query Store,
- aplikacja przechodzi na inny model deploymentu/compatibility.

## References

- [Query Store Troubleshooting](../../troubleshooting/query-store/)
- [Query Store Standard](../../standards/query-store/)
- [QS Compat Report](../../scripts/t-sql/database/QS-Compat-Report/)
