# Deadlock Incident Response — ROLLBACK

## Kiedy
- zmiana index/order/isolation pogarsza workload
- retry powoduje lawinę powtórzeń
- nowy plan jest gorszy

## Procedura
1. Cofnij zmianę schema/query hint/isolation zgodnie z change plan.
2. Wyłącz nadmierny retry, jeśli eskaluje obciążenie.
3. Wróć do poprzedniego planu tylko jeśli został udokumentowany jako poprawny.

## Walidacja
- workload stabilny
- brak nowych regresji
- deadlock frequency znana
