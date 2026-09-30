# Transactional Replication Incident Recovery — PRECHECK

## Sprawdzenia
1. Sprawdź joby agentów.
2. Sprawdź distribution errors/history.
3. Zmierz pending commands.
4. Sprawdź publisher/subscriber connectivity.
5. Zapisz error/article context.
6. Sprawdź miejsce i stan subscriber.

## Evidence before
- agent status
- error number/message
- pending commands
- pub/sub state

## Stop conditions
- proponowana reinit bez RCA
- subscriber ma nieuzgodnione lokalne dane
- snapshot/reinit nie mieści się w oknie
