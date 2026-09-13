# CDC + Debezium + Kafka — Stage 2 Operational Tests

Cel tego etapu: sprawdzić odporność rozwiązania po udanym POC funkcjonalnym.

## Założenia

- baza: `CDC_Lab`
- SQL Server CDC działa dla `dbo.Customer` i `dbo.CustomerOrder`
- job `cdc.CDC_Lab_capture` jest uruchomiony
- kontenery:
  - `sqllab-kafka`
  - `sqllab-debezium-connect`
- connector: `sqllab-sqlserver-cdc`
- topic prefix: `sqllab`

Przed każdym testem warto uruchomić:

```powershell
cd .\scripts\CDC-POC\Debezium
.\03_Status.ps1
.\04_ListTopics.ps1
```

oraz po stronie SQL:

```sql
USE CDC_Lab;
GO
EXEC sys.sp_cdc_help_jobs;
GO
```

## Matryca testów

| Test | Cel | Kryterium PASS | Wynik |
|---|---|---|---|
| 01 Restart Connect | sprawdzić odzyskanie backlogu po zatrzymaniu Debezium | wszystkie zmiany wykonane podczas postoju pojawiają się po restarcie | TODO |
| 02 Restart Kafka | sprawdzić zachowanie Connect po restarcie brokera | connector wraca do RUNNING i kontynuuje publikację | TODO |
| 03 Restart SQL Server | sprawdzić zachowanie CDC i Debezium po restarcie SQL | capture job i connector wracają, brak utraty zmian | TODO |
| 04 Backlog | sprawdzić nadrabianie większej liczby zmian | wszystkie zmiany zostają odczytane po wznowieniu Connect | TODO |
| 05 Rollback | potwierdzić brak eventów dla wycofanej transakcji | rollback nie generuje committed business event | TODO |
| 06 Schema Evolution | sprawdzić zmianę schematu i drugą capture instance | nowa capture instance działa bez przerwania starej | TODO |
| 07 Retention / LSN Gap | sprawdzić zachowanie po utracie potrzebnego LSN | problem jest jednoznacznie wykryty i wymaga re-init | TODO |
| 08 Ordering / Duplicates | sprawdzić kolejność i ponowne dostarczenia | eventy dla jednego klucza zachowują kolejność; konsument jest idempotentny | TODO |
| 09 Operational Checks | zebrać checklistę gotowości operacyjnej | wszystkie kontrolki mają oczekiwany stan | TODO |

## Kolejność wykonywania

Wykonuj testy po kolei. Test 07 celowo ingeruje w retention i powinien być wykonywany dopiero po wcześniejszych testach.

## Pliki

- `01_RestartConnect.ps1`
- `02_RestartKafka.ps1`
- `03_RestartSqlServer.md`
- `04_Backlog.sql`
- `05_Rollback.sql`
- `06_SchemaEvolution.sql`
- `07_RetentionGap.sql`
- `08_OrderingAndDuplicates.sql`
- `09_OperationalChecks.sql`

## Ogólna zasada diagnostyczna

Jeśli event nie pojawia się w Kafka, sprawdzaj warstwy od źródła do końca:

```text
source table
    ↓
transaction log
    ↓
cdc.CDC_Lab_capture
    ↓
cdc.*_CT
    ↓
Debezium connector
    ↓
Kafka topic
    ↓
consumer
```
