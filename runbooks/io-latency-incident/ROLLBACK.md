# I/O Latency Incident — ROLLBACK

## Kiedy
- zmiana index/layout pogarsza inne workloady
- przeniesienie storage nie daje poprawy
- tuning backupu obniża throughput aplikacji

## Procedura
1. Cofnij zmianę access path/config.
2. Przywróć poprzedni layout tylko jeśli bezpieczny i zaplanowany.
3. Ponownie zmierz te same metryki.

## Walidacja
- workload stabilny
- I/O metryki znane
- brak nowych błędów storage
