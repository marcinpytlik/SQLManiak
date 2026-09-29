# Query Performance Incident — RUNBOOK

## 1. Klasyfikuj problem

CPU, I/O, blocking, memory grant, plan regression, parameter sensitivity.

## 2. Porównaj plans/runtime

Query Store jako preferowana historia.

## 3. Wybierz minimalną zmianę

Index, stats, rewrite, force plan/hint lub config tylko przy evidence.

## 4. Testuj na reprezentatywnym workloadzie

Porównaj duration, CPU, reads, waits i row counts.

## 5. Wdróż i obserwuj

Zachowaj plan rollback.
