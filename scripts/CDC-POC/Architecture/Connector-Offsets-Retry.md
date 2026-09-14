# Debezium Connector — offsety, retry i recovery

Ten dokument pełni podobną rolę jak opis workera/retry w POC SSIS: pokazuje, co dzieje się pomiędzy uruchomieniem procesu a faktycznym przetworzeniem zmian.

## 1. Rola connectora

Debezium SQL Server Connector:

1. łączy się z SQL Server,
2. podczas inicjalizacji może wykonać snapshot,
3. odczytuje zmiany dostępne przez SQL Server CDC,
4. zamienia je na eventy Debezium,
5. publikuje eventy do Kafka,
6. zapisuje postęp jako offset Kafka Connect.

Connector nie odczytuje aplikacyjnej tabeli w pętli i nie zastępuje SQL Server CDC capture joba.

## 2. Co oznacza offset

Offset jest punktem postępu connectora. Dzięki niemu po restarcie Debezium nie musi zaczynać od zera.

Model logiczny:

```text
CDC changes
A B C D E F G
        ^
        |
   zapisany offset
```

Po poprawnym restarcie connector kontynuuje od zapisanego punktu i nadrabia zmiany, które są nadal dostępne.

## 3. Retry

Retry może wystąpić m.in. przy chwilowej niedostępności SQL Server lub Kafka.

Istotna zasada: retry nie gwarantuje sukcesu bez końca. Jeżeli connector pozostanie niedostępny na tyle długo, że SQL Server CDC cleanup usunie wymagany zakres LSN, samo ponowne połączenie nie wystarczy.

## 4. Backlog

Przy zatrzymanym Debezium, ale działającym SQL Server CDC:

```text
SQL DML
  |
  v
CDC capture job
  |
  v
cdc.*_CT  <-- backlog rośnie

Debezium OFF
```

Po powrocie Debezium:

```text
stored offset
     |
     v
odczyt zaległych zmian
     |
     v
Kafka
```

Warunek: potrzebne LSN muszą nadal istnieć w CDC.

## 5. Restart connectora

Oczekiwany scenariusz:

```text
RUNNING
-> stop/restart
-> connector odczytuje zapisany offset
-> nadrabia backlog
-> RUNNING
```

Restart nie powinien wymagać nowego snapshotu w zwykłym scenariuszu recovery.

## 6. Utrata LSN

Scenariusz krytyczny:

```text
connector OFF zbyt długo
        |
cleanup CDC usuwa stary zakres
        |
stored offset < min available LSN
        |
RE-INIT REQUIRED
```

Nie należy ręcznie przesuwać offsetu „na oko”, bo tworzy to niewidoczną lukę danych.

Poprawna reakcja to kontrolowany re-init/snapshot zgodnie z runbookiem.

## 7. Duplicate delivery

Po awarii w określonym momencie event może zostać opublikowany ponownie. Dlatego downstream należy projektować jako idempotentny.

Przykładowa strategia konsumenta:

- stabilny klucz biznesowy,
- zapis przetworzonego identyfikatora/wersji,
- UPSERT zamiast ślepego INSERT,
- operacje odporne na ponowne wykonanie.

## 8. Ordering

Kafka zachowuje kolejność w obrębie partycji. Dla zmian tego samego klucza ważne jest spójne partycjonowanie po kluczu rekordu.

Nie należy zakładać globalnej kolejności wszystkich zmian ze wszystkich tabel.

## 9. Capture job a connector

To dwie różne warstwy:

```text
transaction log
     |
cdc.CDC_Lab_capture
     |
cdc.*_CT
     |
Debezium connector
```

Jeżeli capture job stoi, Debezium nie zobaczy nowych zmian mimo statusu `RUNNING`.

To był rzeczywisty problem znaleziony podczas naszego POC.

## 10. Checklista recovery

Po awarii sprawdź kolejno:

```text
[ ] SQL Server ONLINE
[ ] SQL Server Agent działa
[ ] capture job działa
[ ] sys.dm_cdc_errors bez krytycznego błędu
[ ] wymagany LSN nadal jest w retencji
[ ] Kafka działa
[ ] Connect działa
[ ] connector RUNNING
[ ] task RUNNING
[ ] topic przyjmuje nowe eventy
[ ] lag maleje
```
