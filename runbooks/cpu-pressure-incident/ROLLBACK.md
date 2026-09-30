# CPU Pressure Incident — ROLLBACK

## Kiedy
- CPU spada kosztem throughput
- plan forcing/hint pogarsza inne parametry
- zmiana parallelism daje regresję

## Procedura
1. Cofnij forcing/hint/config zmianę.
2. Przywróć poprzedni MAXDOP/cost threshold tylko jeśli były częścią zatwierdzonej zmiany.
3. Ponownie zmierz pełny zestaw sygnałów.

## Walidacja
- throughput/latency wróciły
- scheduler pressure znany
- brak nowych regresji
