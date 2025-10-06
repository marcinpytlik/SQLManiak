# PerfMon — liczniki do monitorowania „elfów”

Dodaj (wg potrzeb instancje/DB):

- **SQLServer:Buffer Manager** → `Lazy Writes/sec`, `Page life expectancy`, `Checkpoint pages/sec`
- **SQLServer:Databases** → `Log Flushes/sec`, `Log Bytes Flushed/sec`, `Log Flush Wait Time`
- **SQLServer:General Statistics** → `Ghost Cleanup tasks/sec`
- **SQLServer:Transactions** → `Log Flushes/sec` (na poziomie DB)
- **Process(sqlservr)** → `% Processor Time`, `Working Set`, `Private Bytes`
- **System** → `Memory Available MBytes`
- **PhysicalDisk / LogicalDisk** → `Avg. Disk sec/Read`, `Avg. Disk sec/Write`, `Disk Transfers/sec`

Wskazówki:
- Jeśli `Lazy Writes/sec` rośnie skokowo → presja na Buffer Pool (spójrz na Resource Monitor).
- Duże `Log Flushes/sec` przy wysokim `Avg. Disk sec/Write` → ograniczenie I/O logu (WRITELOG waits).
- `Ghost Cleanup tasks/sec` ≫ 0, a jednocześnie wzrost fragmentacji → intensywne DELETE/UPDATE.
