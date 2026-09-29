# Blocking Emergency Mitigation — ROLLBACK

## Kiedy
- interwencja pogarsza sytuację
- KILL uruchamia bardzo długi rollback
- zmiana izolacji/hintu wprowadza skutki uboczne

## Procedura
1. Nie wykonuj kolejnych KILL bez ponownej oceny.
2. Cofnij tymczasowe zmiany query hint/isolation, jeśli były użyte.
3. Pozwól rollback zakończyć się i monitoruj jego postęp zamiast restartować SQL Server.

## Walidacja
- baza stabilna
- brak lawiny nowych blockerów
- transakcje kończą się poprawnie
