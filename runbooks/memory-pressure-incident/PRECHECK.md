# Memory Pressure Incident — PRECHECK

1. Sprawdź OS memory i SQL max server memory.
2. Sprawdź Memory Grants Pending.
3. Sprawdź RESOURCE_SEMAPHORE delta.
4. Sprawdź PLE względem baseline i lazy writes.
5. Znajdź duże active/pending grants oraz plany.

## Evidence before
- OS/SQL memory
- grants pending
- RESOURCE_SEMAPHORE
- PLE/lazy writes
- top grants/plans

## Stop conditions
- planowana zmiana max server memory bez OS/SQL evidence
- diagnoza opiera się tylko na PLE
- nie rozróżniono query grant pressure od buffer pool/OS pressure
