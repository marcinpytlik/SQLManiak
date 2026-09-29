# Availability Group Planned Failover — PRECHECK

## Kontekst

Zapisz:

```text
Server / instance:
Database / component:
Incident or change window:
Business impact:
Owner:
Expected result:
```

## Sprawdzenia przed wykonaniem

1. Potwierdź stan WSFC/quorum.
2. Sprawdź role replik i synchronization_health.
3. Dla planowanego failover wymagającego braku utraty danych potwierdź odpowiedni stan synchronizacji repliki docelowej.
4. Sprawdź log send queue i redo queue.
5. Sprawdź listener/DNS/TCP z punktu widzenia klienta.
6. Zanotuj availability mode i failover mode.

## Evidence before

- role przed zmianą
- synchronization health
- log send/redo queue
- listener connectivity
- czas rozpoczęcia

## Stop conditions

- replika docelowa nie jest gotowa do przejęcia roli
- WSFC/quorum jest niestabilne
- bazy są w stanie suspended/not synchronizing bez wyjaśnienia
