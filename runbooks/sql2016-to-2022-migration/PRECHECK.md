# SQL Server 2016 to 2022 Migration — PRECHECK

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

1. Uruchom precheck/dry-run.
2. Potwierdź miejsce na destination.
3. Zidentyfikuj features oraz zależności poza bazą: logins, jobs, linked servers, credentials, proxies, crypto.
4. Zweryfikuj test restore.
5. Ustal freeze/cutover i rollback period.
6. Potwierdź source/destination backup path i service-account access.

## Evidence before

- precheck logs
- config snapshot source/destination
- lista baz
- lista dependencies
- baseline Query Store/performance
- plan rollback

## Stop conditions

- precheck ma unresolved FAIL
- brak miejsca
- brak kluczy/certyfikatów dla TDE
- test restore nieudany
- brak akceptacji cutover
