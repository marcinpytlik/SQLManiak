# Memory Internals – SQL Server 2022

Pakiet do diagnozy pamięci SQL Server: Buffer Pool, Memory Clerks, PLE, Lazy Writer, Memory Grants.
Wymagane uprawnienie: `VIEW SERVER STATE`.

## Szybki start
1. `scripts/Target_vs_Total_Server_Memory.sql`
2. `scripts/BufferPool_PLE_Counters.sql`
3. `scripts/Memory_Clerks_Overview.sql`
4. `scripts/Memory_Grants_Status.sql`
5. `scripts/LazyWriter_Checkpoint_Stats.sql`
6. (opcjonalnie) `scripts/BufferPool_ModifiedPages.sql`
7. `scripts/Waits_Memory_Pressure.sql`

## Uwaga
Skrypty są **diagnostyczne** – nie zmieniają konfiguracji.
