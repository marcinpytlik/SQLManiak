# SQL Server Patching — ROLLBACK

## Kiedy użyć

- SQL Server nie startuje po patchu
- krytyczna funkcjonalność nie działa
- HA nie wraca do zdrowego stanu

## Procedura

1. Zatrzymaj dalsze patchowanie kolejnych node.
2. Zastosuj zatwierdzoną metodę uninstall/rollback patchu, jeżeli wspierana i przewidziana.
3. Przywróć poprzedni owner/aktywny node w FCI, jeśli patchowano pasywny node i jest to bezpieczne.
4. Odtwórz stan jobów zgodnie ze snapshotem.

## Po rollback

- poprzedni build/stan usług
- aplikacja działa
- joby zgodne ze snapshotem
- monitoring i HA stabilne

## Eskalacja

Jeżeli rollback nie przywraca stabilnego stanu, zatrzymaj kolejne zmiany, zachowaj evidence i eskaluj zgodnie z procedurą incydentową.
