# CPU Pressure Incident — RUNBOOK

## 1. Potwierdź presję

Korelacja CPU + runnable + signal waits + app impact.

## 2. Znajdź workload

Active requests, Query Store i plan cache.

## 3. Zidentyfikuj plan/root cause

Regresja, reads, cardinality, parameter sensitivity, compile storm, parallelism.

## 4. Wdróż najmniejszą mitigację

Query/plan/index/forcing/workload throttling zgodnie z RCA.

## 5. Mierz efekt

CPU, runnable, throughput i latency razem.
