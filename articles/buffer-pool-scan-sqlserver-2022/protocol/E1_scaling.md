# E1 — Buffer Pool Size Scaling (pilot)

## Goal
Observe Buffer Pool Scan events as resident data pages increase. Do not infer parallel speed-up when scans remain serial.

## Sequence
1. On Windows: `Get-PSDrive C` and `docker stats --no-stream`. Stop if free C: space is insufficient; avoid filling the VHDX.
2. Run `sql/05_e1_setup.sql` only once.
3. For each target 512, 1024, 2048 MiB, adjust `@TargetMiB` in `sql/06_e1_fill.sql`. Repeat the script if it reports `CONTINUE_IN_NEXT_RUN`. Track database file sizes on C:.
4. Confirm XE is **RUNNING**. `01_create_xe.sql` recreates the session, so do not run it mid-series without preserving prior XEL files.
5. Run `sql/07_e1_measure.sql` with matching `@RunLabel`. Record all result sets.
6. Stop XE using `03_stop_xe.sql`; read via `02_read_xe.sql`.
7. Save metadata and filtered raw results outside Git, e.g. local `results/` directory.

## Caveats
- SQL memory limit: 10240 MB; 4 schedulers. Typical scans may remain serial at all tested sizes.
- `buffer_pool_scan_complete` fires only for scans over the configured threshold; rely also on task events.
- `DATALENGTH(Payload)` forces data access but validate with `LabBufferCount`.
- Single measurement per stage is a pilot, **not** statistically significant. Add repetitions only after verifying the workload and observation.
- `ALTER DATABASE OFFLINE` removes the database from availability. Only ever run in this dedicated lab instance.
- Do not automatically DROP database, DELETE volumes, compact VHDX or use global DBCC DROPCLEANBUFFERS.
