# Query Performance Incident — PRECHECK

1. Ustal query_id/query_hash lub tekst.
2. Zdefiniuj baseline i incident window.
3. Sprawdź Query Store, potem plan cache fallback.
4. Sprawdź blocking/waits.
5. Porównaj plany, stats, indexes, parameters.

## Evidence before
- query text/id/hash
- plan before/after
- CPU/duration/reads
- waits
- blocking context

## Stop conditions
- planowana zmiana index/hint bez plan evidence
- brak rozróżnienia CPU vs wait-bound
- test wykonywany na niereprezentatywnych parametrach
