# ADR-001 — SQL Server CDC + Debezium + Kafka

## Status

Proposed / POC validated functionally. Final acceptance depends on Stage 4 and Stage 5.

## Kontekst

Potrzebujemy mechanizmu publikowania zatwierdzonych zmian z SQL Server do systemów downstream bez wprowadzania dual-write do kodu aplikacji.

Rozważany model:

```text
SQL Server transaction log
        |
        v
SQL Server CDC
        |
        v
Debezium
        |
        v
Kafka
        |
        v
Consumers
```

## Decyzja

Do pilotażu przyjmujemy architekturę opartą o natywne SQL Server CDC jako źródło zmian, Debezium jako connector CDC oraz Kafka jako warstwę transportową.

## Uzasadnienie

- brak konieczności modyfikowania każdej operacji DML w aplikacji,
- zmiany wynikają z zatwierdzonego transaction loga,
- Debezium obsługuje snapshot + streaming,
- offset connectora pozwala wznowić pracę po restarcie,
- Kafka oddziela producenta zmian od wielu konsumentów,
- rozwiązanie można monitorować warstwa po warstwie.

## Konsekwencje

### Pozytywne

- luźne powiązanie źródła i konsumentów,
- możliwość wielu downstreamów,
- łatwiejszy replay w granicach retencji Kafka,
- centralny model obserwowalności,
- brak synchronicznego dual-write w transakcji aplikacyjnej.

### Negatywne / ryzyka

- CDC wymaga działającego SQL Server Agent i capture joba,
- retention CDC staje się elementem RPO dla pipeline,
- schema evolution wymaga procedury,
- Kafka/Debezium zwiększają liczbę komponentów operacyjnych,
- delivery należy traktować co najmniej jako at-least-once z perspektywy projektowania konsumenta; consumer powinien być idempotentny,
- utrata wymaganego zakresu LSN wymusza re-init/snapshot.

## Odrzucone uproszczenie

Nie przyjmujemy założenia, że `connector = RUNNING` oznacza zdrowy pipeline. Realny test POC wykazał, że connector może działać, a nowe zdarzenia nie płyną, jeżeli `cdc.CDC_Lab_capture` jest zatrzymany.

## Zasada operacyjna

Monitoring musi obejmować cały łańcuch:

```text
source DML
-> CDC capture
-> CT
-> Debezium
-> Kafka
-> consumer lag
```

## Warunek decyzji GO

ADR może zmienić status na Accepted po przejściu Stage 4 oraz Stage 5 i wykonaniu pilotażu na rzeczywistej tabeli.
