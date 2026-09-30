# I/O Latency Incident — RUNBOOK

## 1. Potwierdź warstwę

Rozdziel data, log, TempDB i backup path.

## 2. Porównaj latency i workload

Normalna latency + ogromne reads wskazuje raczej workload niż storage.

## 3. Znajdź źródło I/O

Query plan, maintenance, backup, growth, checkpoint, ETL.

## 4. Wdróż minimalną zmianę

Query/index/layout/storage zgodnie z RCA.

## 5. Zmierz ponownie

Porównaj latency, throughput, waits i app response.
