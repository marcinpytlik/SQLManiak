# SQL Agent Job Recovery — ROLLBACK

## Kiedy
- retry powoduje skutki uboczne
- security fix jest zbyt szeroki
- job częściowo modyfikuje dane

## Procedura
1. Zatrzymaj schedule, jeśli kolejne uruchomienia są ryzykowne.
2. Cofnij tymczasowe permission/proxy.
3. Uruchom zatwierdzoną procedurę cofnięcia skutków biznesowych, jeśli istnieje.

## Walidacja rollback
- brak dalszych niekontrolowanych zmian
- security wróciło do właściwego stanu
- dane/output spójne
