# Memory Pressure Incident — RUNBOOK

## 1. Określ typ pressure

OS, buffer pool, query grants lub external process.

## 2. Znajdź workload

Duże grants, concurrency, sort/hash, cardinality.

## 3. Wdróż minimalną mitigację

Query/plan/index/concurrency/config zgodnie z przyczyną.

## 4. Obserwuj recovery

Pending grants, waits, PLE trend i latency.

## 5. RCA

Ustal, czy potrzebna jest trwała zmiana memory config lub workloadu.
