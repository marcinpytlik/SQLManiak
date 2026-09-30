# SQL Server 2016 to 2022 Migration — ROLLBACK

## Kiedy użyć

- krytyczna aplikacja nie działa
- nieakceptowalna regresja bez szybkiej mitigacji
- brak krytycznej zależności na destination

## Procedura

1. Zatrzymaj writes na destination przed decyzją o powrocie.
2. Ustal, czy dane zapisane na destination wymagają synchronizacji/eksportu — nie zakładaj automatycznego reverse restore.
3. Jeżeli source nadal jest poprawnym punktem rollback i pozostał READ_ONLY, przywróć go do uzgodnionego stanu i routing aplikacji.
4. Udokumentuj rozbieżność danych i decyzję biznesową.

## Po rollback

- aplikacja wróciła do zatwierdzonego source
- source jest w poprawnym stanie writes
- nie ma równoległych niezależnych writes
- monitoring i joby działają

## Eskalacja

Jeżeli rollback nie przywraca stabilnego stanu, zatrzymaj kolejne zmiany, zachowaj evidence i eskaluj zgodnie z procedurą incydentową.
