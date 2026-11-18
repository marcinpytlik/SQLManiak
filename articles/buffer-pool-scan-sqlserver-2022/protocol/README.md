# Protokół pomiarowy

Dla każdej serii zachować: timestamp, @@VERSION i CU, identyfikator serii, konfigurację RAM/CPU, liczbę schedulerów, faktyczną liczbę buforów, parametry workloadu, czasy operacji, Extended Events, liczbę powtórzeń i wyniki surowe.

H1: czas a liczba buforów; H2: zadania a liczba buforów; H3: równoległość a czas; H4: konkurencja skanów; H5: małe bazy.

Brak XE nie jest dowodem braku skanu. Nie utożsamiać czasu CREATE DATABASE z czasem skanowania.
