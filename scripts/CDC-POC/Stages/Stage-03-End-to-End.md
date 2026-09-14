# Stage 3 — End-to-End

## Cel

Potwierdzić pełny przepływ od zatwierdzonej transakcji SQL Server do eventu Kafka.

## Uruchomienie

W PowerShell:

```powershell
cd .\scripts\CDC-POC\Debezium
.\05_Consume.ps1 -FromBeginning
```

W SSMS:

```text
Debezium/06_TestChanges.sql
```

## Oczekiwane operacje

```text
r = snapshot/read
c = insert/create
u = update
d = delete
```

## Kryterium PASS

- INSERT trafia do Kafka jako `c`,
- UPDATE trafia jako `u`,
- DELETE trafia jako `d`,
- consumer czyta właściwy topic,
- source metadata pozwala wskazać bazę/tabelę i pozycję źródłową.

## Kontrola warstwa po warstwie

Jeżeli event się nie pojawia, nie zaczynaj od Kafka. Sprawdź kolejno źródło, CT, capture job, connector, topic i consumer.
