# Availability Group Planned Failover — RUNBOOK

## 1. Potwierdź stan AG

Zbierz stan grupy, replik i baz z DMV HADR oraz monitoringu.

## 2. Wykonaj planned failover

Wykonaj przełączenie zgodnie z konfiguracją AG z repliki przygotowanej do przejęcia roli. Nie używaj forced failover w zwykłym maintenance.

## 3. Zweryfikuj role

Potwierdź nowy Primary i role pozostałych replik.

## 4. Zweryfikuj listener

Połącz się przez listener/VNN, nie przez fizyczną nazwę node.

## 5. Obserwuj kolejki

Sprawdź, czy log send/redo queues stabilizują się po zmianie roli.

## Przejście do walidacji

Po wykonaniu procedury przejdź do [VALIDATION.md](VALIDATION.md).
