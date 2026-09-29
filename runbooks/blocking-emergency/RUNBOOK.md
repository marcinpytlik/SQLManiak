# Blocking Emergency Mitigation — RUNBOOK

## 1. Zabezpiecz evidence

Zrób blocking snapshot i zapisz chain.

## 2. Oceń impact

Policz blocked sessions i SLA impact.

## 3. Usuń przyczynę bez KILL, jeśli możliwe

Np. zakończ kontrolowanie proces aplikacyjny lub popraw dependency.

## 4. Awaryjne KILL tylko po decyzji

Jeżeli zatwierdzone, przerwij konkretną sesję head blocker i monitoruj rollback.

## 5. Obserwuj odbudowę workloadu

Sprawdź LCK waits, timeouty i throughput.
