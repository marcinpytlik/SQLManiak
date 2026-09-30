# Deadlock Incident Response — RUNBOOK

## 1. Pobierz graph

Użyj system_health/investigate zamiast tworzyć od razu nową sesję XE.

## 2. Zrekonstruuj cykl

Określ kto trzyma zasób A i chce B oraz odwrotnie.

## 3. Znajdź klasę root cause

Access order, long transaction, index/access path, conversion, range locks, parallelism.

## 4. Wdróż minimalną zmianę

Preferuj spójny order, krótsze transakcje, właściwy index lub zmianę kodu.

## 5. Dodaj retry jako resilience, jeśli właściwe

Retry obsługuje symptom po stronie aplikacji, ale nie zastępuje RCA.
