# Log Shipping DR Failover — ROLLBACK

## Kiedy użyć

- DR nie przechodzi ONLINE
- aplikacja nie może pracować na Secondary
- osiągnięty punkt danych jest nieakceptowalny

## Procedura

1. Jeżeli RECOVERY nie zostało wykonane, zachowaj secondary w stanie umożliwiającym dalsze restore.
2. Jeżeli Primary jest zdrowy i nadal źródłem prawdy, przywróć routing do Primary.
3. Po pracy na DR zaplanuj re-seed/reinicjalizację Log Shipping przed failback.

## Po rollback

- wybrana strona jest jednoznacznym źródłem writes
- routing jest spójny
- nie ma równoległych niezależnych writes po obu stronach

## Eskalacja

Jeżeli rollback nie przywraca stabilnego stanu, zatrzymaj kolejne zmiany, zachowaj evidence i eskaluj zgodnie z procedurą incydentową.
