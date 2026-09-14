# Stage 5 — Production Readiness

## Cel

Przejść z działającego POC do kontrolowanego pilotażu produkcyjnego.

## 1. Monitoring

Sprawdź możliwość monitorowania:

- statusu `cdc.<db>_capture`,
- `sys.dm_cdc_errors`,
- opóźnienia capture,
- rozmiaru change tables,
- wieku najstarszego dostępnego LSN,
- statusu connector/task Debezium,
- Kafka lag,
- braku nowych eventów mimo aktywności źródła.

## 2. Security

Do decyzji przed pilotem:

- minimalne uprawnienia loginu Debezium,
- bezpieczne przechowywanie hasła/secretu,
- TLS do SQL Server i Kafka,
- ewentualny model AD/Kerberos,
- brak haseł w repo.

## 3. HA / failover

Jeżeli źródło działa na FCI/AG, przetestuj:

- failover SQL Server,
- reconnect Debezium,
- DNS/VNN/listener,
- zachowanie capture joba po failoverze,
- brak luki w publikowanych zmianach.

## 4. Capacity

Zmierz:

- liczbę zmian/s,
- wzrost `cdc.*_CT`,
- wzrost transaction loga,
- maksymalny backlog,
- czas nadrabiania backlogu,
- minimalny bezpieczny retention.

Zależność krytyczna:

```text
maksymalny czas niedostępności konsumenta < retention CDC - bufor bezpieczeństwa
```

## 5. Schema governance

Zmiana schematu tabeli objętej CDC nie może być traktowana jak zwykły ALTER TABLE bez kontroli downstreamu.

Preferowany model:

```text
old capture instance
        +
new capture instance v2
        |
migracja konsumenta
        |
walidacja
        |
usunięcie starej instancji
```

## 6. Runbook

Operator powinien mieć procedurę dla:

- capture job stopped,
- connector FAILED,
- Kafka unavailable,
- SQL unavailable,
- LSN gap,
- schema change,
- re-init/snapshot,
- backlog recovery.

## 7. Pilot

Zalecany pierwszy pilot:

- 1–2 rzeczywiste tabele,
- realny profil zmian,
- kilka dni obserwacji,
- monitoring i alerty aktywne,
- zapisane wyniki i incydenty.

## GO / NO-GO

### GO

- wszystkie testy krytyczne PASS,
- nie ma niewyjaśnionej utraty danych,
- recovery jest powtarzalne,
- retention ma bezpieczny zapas,
- monitoring pozwala szybko wskazać uszkodzoną warstwę,
- security i secrets są zaakceptowane,
- schema change ma procedurę.

### NO-GO

- nie potrafimy wykryć zatrzymanego capture joba,
- offset może wypaść poza retention bez alertu,
- failover/restart powoduje niewyjaśnione luki,
- consumer nie radzi sobie z ponownym dostarczeniem,
- nie ma procedury re-init,
- hasła lub dostęp są zarządzane ad hoc.

## Wynik Stage 5

Nie „produkcja”, tylko świadoma decyzja:

```text
GO -> pilot
NO-GO -> poprawka -> ponowny test
```
