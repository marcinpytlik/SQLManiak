# Lab 05 — Wait Stats Clinic (diagnostyka przyczyn)

Cel:
- Złapać **snapshot waitów**, odpalić workload, policzyć **DELTA** i zmapować waity do kategorii (CPU, IO, Memory, Parallelism, Network, Locks).
- Zbudować mini „narzędzie” DBA w czystym T-SQL do szybkiej diagnozy.

## Plan
1. **Reset (opcjonalnie)**: zapisujemy snapshot początkowy (nie kasujemy globalnych waitów).
2. **Workload**: skrypt generujący różne waity (I/O, CPU, parallelism).
3. **Delta**: porównujemy `sys.dm_os_wait_stats` (poza benign: SLEEP_TASK, LAZYWRITER_SLEEP, itp.).
4. **Mapa**: heurystyczne mapowanie waitów do kategorii.
