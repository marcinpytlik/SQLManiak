# Memory Pressure Incident — ROLLBACK

## Kiedy
- zmiana memory config powoduje OS pressure lub paging
- plan hint/forcing pogarsza inne zapytania
- ograniczenie concurrency narusza SLA

## Procedura
1. Przywróć poprzedni memory config zgodnie z change plan.
2. Cofnij hint/forcing.
3. Ponownie zmierz grants, OS memory i workload.

## Walidacja
- OS/SQL stabilne
- brak nowych grant waits
- latency akceptowalna
