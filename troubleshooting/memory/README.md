# Troubleshooting: Memory

## Symptoms

- wysokie Memory Grants Pending,
- niskie PLE względem normalnego baseline,
- częste lazy writes,
- presja na workspace memory,
- zapytania czekające na grant pamięci,
- niestabilna wydajność po zmianie workloadu.

## First checks

1. Target vs Total Server Memory.
2. PLE i Buffer Pool.
3. Memory Clerks.
4. Memory Grants.
5. Lazy Writer / Checkpoint.
6. Waits związane z presją pamięci.

## Existing source of truth

Pakiet [Memory Internals](../../docs/MemoryInternals/README.md):

1. [Target_vs_Total_Server_Memory.sql](../../docs/MemoryInternals/scripts/Target_vs_Total_Server_Memory.sql)
2. [BufferPool_PLE_Counters.sql](../../docs/MemoryInternals/scripts/BufferPool_PLE_Counters.sql)
3. [Memory_Clerks_Overview.sql](../../docs/MemoryInternals/scripts/Memory_Clerks_Overview.sql)
4. [Memory_Grants_Status.sql](../../docs/MemoryInternals/scripts/Memory_Grants_Status.sql)
5. [LazyWriter_Checkpoint_Stats.sql](../../docs/MemoryInternals/scripts/LazyWriter_Checkpoint_Stats.sql)
6. [BufferPool_ModifiedPages.sql](../../docs/MemoryInternals/scripts/BufferPool_ModifiedPages.sql)
7. [Waits_Memory_Pressure.sql](../../docs/MemoryInternals/scripts/Waits_Memory_Pressure.sql)
8. [Workspace_Memory_Current_Grants.sql](../../docs/MemoryInternals/scripts/Workspace_Memory_Current_Grants.sql)

## Diagnosis

Nie traktuj pojedynczego wskaźnika jako root cause.

Przykładowo niski PLE może być skutkiem zmiany workloadu, dużego skanu, presji zewnętrznej albo niewłaściwego rozmiaru pamięci. Zawsze koreluj kilka sygnałów.

## Validation

Po zmianie porównaj:

- Memory Grants Pending,
- grant wait time,
- PLE względem baseline,
- lazy writes,
- waits,
- czas i CPU zapytań.
