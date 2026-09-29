# Availability Group Planned Failover — ROLLBACK

## Kiedy użyć

- listener nie kieruje ruchu poprawnie
- nowy Primary jest niestabilny
- krytyczne bazy nie osiągają oczekiwanego stanu

## Procedura

1. Ustal, czy poprzedni Primary jest gotowy do bezpiecznego przejęcia roli.
2. Jeżeli warunki synchronizacji na to pozwalają, wykonaj kontrolowany failback.
3. Zweryfikuj listener i wszystkie bazy po powrocie.

## Po rollback

- Primary zgodny z rollback planem
- listener działa
- bazy stabilne
- kolejki maleją

## Eskalacja

Jeżeli rollback nie przywraca stabilnego stanu, zatrzymaj kolejne zmiany, zachowaj evidence i eskaluj zgodnie z procedurą incydentową.
