# SQL Server FCI Failover — ROLLBACK / FAILBACK

## Kiedy rozważyć rollback

Jeżeli po failover:

- SQL resource nie przechodzi online,
- VNN nie jest osiągalny,
- shared storage nie działa poprawnie,
- TempDB nie może zostać utworzony,
- aplikacja nie odzyskuje połączenia.

## 1. Zbierz evidence

Przed kolejnym przełączeniem zachowaj:

- Cluster state,
- failed resources,
- SQL ERRORLOG,
- Windows Event Log,
- informacje o TempDB,
- czas i komunikaty błędów.

## 2. Powrót na poprzedni node

Jeżeli poprzedni node jest nadal znany jako poprawny i gotowy do pracy:

```powershell
Move-ClusterGroup "SQL Server (MSSQLSERVER)" -Node <PreviousNode>
```

## 3. Powtórz walidację

Po powrocie wykonaj komplet z:

- [VALIDATION.md](VALIDATION.md)

w szczególności:

- owner node,
- resources,
- VNN,
- TempDB,
- SQL Agent,
- application connectivity.

## 4. Failback po awarii

Nie wykonuj failback tylko dlatego, że pierwotny node ponownie jest online.

Najpierw ustal przyczynę problemu i potwierdź stabilność node, storage i wymaganych ścieżek.

## Stop conditions

Przerwij kolejne przełączenia i eskaluj, gdy:

- zasoby nie przechodzą online na żadnym node,
- quorum jest zagrożone,
- shared storage jest niedostępny,
- oba node mają problem z lokalnym TempDB,
- kolejne przełączenie zwiększa ryzyko niedostępności.
