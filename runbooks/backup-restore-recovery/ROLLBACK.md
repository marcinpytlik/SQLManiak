# Backup / Restore / Recovery — ROLLBACK

## Restore test / alternatywna baza

Najbezpieczniejszy wariant testowy odtwarza bazę pod inną nazwą.

Jeżeli walidacja nie powiedzie się:

1. Zachowaj logi i komunikaty błędów.
2. Nie traktuj testu jako potwierdzenia recoverability.
3. Usuń bazę testową dopiero po zabezpieczeniu evidence.
4. Popraw chain, ścieżki, miejsce lub konfigurację.
5. Powtórz pełny test.

## Restore zatrzymany w NORECOVERY

Jeżeli baza pozostaje w `RESTORING` i brakuje kolejnego elementu chaina:

- nie wykonuj `RECOVERY` tylko po to, aby „coś zrobić”,
- ustal, czy właściwy backup można pozyskać,
- eskaluj, jeżeli wymagany restore point nie jest osiągalny.

## Recovery produkcyjne

Jeżeli procedura dotyczy zastąpienia aktywnej bazy produkcyjnej, traktuj ją jako osobną kontrolowaną zmianę.

Przed zmianą wymagane są co najmniej:

- potwierdzony restore point,
- potwierdzony chain,
- plan przełączenia aplikacji,
- decyzja dotycząca bieżącego stanu danych,
- uzgodnione RPO/RTO.

## Stop conditions

Przerwij i eskaluj, gdy:

- restore chain jest nieciągły,
- CHECKDB wykazuje problem,
- baza nie przechodzi do ONLINE,
- osiągnięty restore point nie spełnia RPO,
- całkowity czas recovery przekracza dopuszczalne RTO i wymaga zmiany strategii.
