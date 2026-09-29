# Availability Group Planned Failover — VALIDATION

## Kryteria sukcesu

- nowy Primary jest zgodny z planem
- bazy są ONLINE
- listener obsługuje połączenia
- synchronization health wraca do oczekiwanego stanu
- brak nieplanowanej utraty danych
- aplikacja odzyskała połączenie

## Evidence after

Zachowaj:

- role replik po failover
- queue sizes
- czas disconnect/reconnect
- SQL ERRORLOG/cluster evidence

## Zamknięcie

Nie zamykaj zmiany/incydentu tylko dlatego, że pojedynczy krok zakończył się sukcesem. Potwierdź rezultat techniczny oraz wpływ na usługę.
