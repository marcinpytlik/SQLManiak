# SQLManiak SqlClient Pool Benchmark

Laboratory benchmark comparing **Microsoft.Data.SqlClient 7.1.0** connection pools **V1** and **V2**, using **.NET 10** and SQL Server 2022.

Companion to the [SQLManiak article](https://sqlmaniak.blog/posts/sqlclient-connection-pool-v2-benchmark/) dated November 5, 2026.

## Requirements

.NET 10 SDK, PowerShell 7, and a disposable SQL Server laboratory instance. The benchmark opens connections; it does not execute T-SQL statements. Five hundred simultaneous physical connections can cause significant load. Run only in a controlled lab.

```powershell
$env:SQLCLIENT_BENCH_CS = 'Server=localhost;Database=master;Integrated Security=True;Encrypt=True;TrustServerCertificate=True'
dotnet restore
dotnet build -c Release

./Run-Random500.ps1 -Trials 500 -Seed 20261104 -Levels 10,25,50,100,200,500 -MaxPool 550
./Run-Diagnostic.ps1 -Trials 280 -Seed 20261104 -Levels 200,250,300,350,400,450,500 -MaxPool 550
dotnet tool install --global dotnet-trace
./Run-Profile.ps1 -Levels 300,400,500 -Repetitions 5 -MaxPool 550
```

`TrustServerCertificate=True` is **lab-only**; use validated certificates for production. Set the connection string only through `SQLCLIENT_BENCH_CS`. Do not commit credentials, raw ETW traces, or machine-specific logs.

## Methodology

- Two modes: synchronous `Open()`, asynchronous `OpenAsync()`.
- V1 and V2 use **separate .NET processes**; the AppContext switch is set before SqlClient initialization.
- Each round opens N connections and holds them until all open attempts finish; no SQL commands are issued.
- A barrier separates LongRunning sync-worker setup from timed opening.
- Randomized runs use a deterministic seed and a fresh process per trial, with CSV results.
- Profiling runs use `ClearAllPools()` between rounds **within one process**; they are not equivalent to new-process measurements.
- `process_cpu_ms` is total CPU time across cores. The experiment focuses on *cold-pool creation*, not query performance or a warmed-up pool.

This folder contains the benchmark source and the three laboratory PowerShell runners. Results depend on authentication, SQL Server, TLS, CPU scheduling, and environment. The source is licensed under the repository's CC BY 4.0 license (`License.txt`).
