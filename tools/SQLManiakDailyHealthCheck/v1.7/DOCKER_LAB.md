# SQLManiak DHC v1.7 — Docker Lab

Disposable local lab with **two separate SQL Server 2022 Developer (Linux)** instances:

| Role | Compose service | SSMS (Windows host) | Purpose |
|---|---|---|---|
| Repository | `sql-repository` | `127.0.0.1,15433` | Persistent `SQLManiakHealthHistory` |
| Target | `sql-target` | `127.0.0.1,15434` | Source for Daily Health Check and TempDB diagnostics |

Docker data is in **two named volumes**. Both TCP ports are bound to loopback only. This lab is not production-ready and does **not** test Windows/WSFC/FCI-specific checks.

## Prerequisites

- Docker Desktop with Linux containers and at least ~6 GiB available for this lab plus other running services.
- PowerShell 7.5+ and `SqlServer` PowerShell module for the complete DHC smoke test.
- SQL Server Management Studio (SSMS) on Windows.
- Existing `SQLManiak_Daily_Health_Check_v1_5_CSV.sql` (**not included** in v1.7).
- SQL Server credentials are for **lab only**. Never commit a real `.env` file.

## 1. Start two containers

From `C:\Users\blad\Documents\GitHub\SQLManiak\tools\SQLManiakDailyHealthCheck\v1.7`:

```powershell
Copy-Item .env.example .env
notepad .env # Replace both placeholder passwords with different, strong values

docker compose -f compose.yaml config --quiet
docker compose -f compose.yaml up -d
docker compose -f compose.yaml ps
```

The service healthchecks run `/opt/mssql-tools18/bin/sqlcmd` inside each SQL container. If an image version does not include this executable, the check will report `unhealthy` even if SQL Server is running: inspect `docker compose logs`, then verify connectivity from SSMS.

### Connect using SSMS

Connect with SQL Server Authentication as `sa` using the password assigned to each service in local `.env`. For this local lab enable **Trust server certificate**. **Do not** use Windows Authentication.

## 2. Create the repository and check source DMVs

1. Connect to **`127.0.0.1,15433`** and execute **`01_Repository.sql`**. Confirm that `SQLManiakHealthHistory` exists.
2. Connect to **`127.0.0.1,15434`** and execute **`02_TempDB_Collect.sql`**. It should produce exactly three result sets: `TEMPDB_OVERVIEW`, `TEMPDB_SESSIONS`, `TEMPDB_FILES`.
3. Do not execute `01_Repository.sql` on the target unless you explicitly want an additional repository database there.

## 3. Execute complete DHC v1.7 (optional)

`03_Run-DHC-v1_7.ps1` executes the existing SQLManiak DHC v1.5 query against the **target** and writes its results plus TempDB results to the **repository**. You must supply the original `SQLManiak_Daily_Health_Check_v1_5_CSV.sql` file separately.

Use passwords interactively; this example builds a connection string in process, without hard-coding a password in a script:

```powershell
Import-Module SqlServer
Add-Type -AssemblyName Microsoft.Data.SqlClient

$targetCredential = Get-Credential -UserName sa -Message 'Target (15434) sa password'
$repoSecret = Read-Host 'Repository (15433) sa password' -AsSecureString
$repoCredential = [pscredential]::new('sa', $repoSecret)

$builder = [Microsoft.Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder.DataSource = '127.0.0.1,15433'
$builder.InitialCatalog = 'SQLManiakHealthHistory'
$builder.UserID = 'sa'
$builder.Password = $repoCredential.GetNetworkCredential().Password
$builder.Encrypt = [Microsoft.Data.SqlClient.SqlConnectionEncryptOption]::Mandatory
$builder.TrustServerCertificate = $true
$builder.PersistSecurityInfo = $false

.\03_Run-DHC-v1_7.ps1 `
  -ServerInstance '127.0.0.1,15434' `
  -RepositoryConnectionString $builder.ConnectionString `
  -SqlCredential $targetCredential `
  -SqlFile 'C:\PATH\TO\SQLManiak_Daily_Health_Check_v1_5_CSV.sql' `
  -TrustServerCertificate

Remove-Variable builder, repoCredential, repoSecret, targetCredential
```

For first smoke testing, `sa` credentials simplify setup. Replace them with separate least-privilege SQL logins for routine testing. DHC v1.5 is Windows/FCI-oriented and some sections may return warnings/errors on Linux, even while the repository and TempDB-specific diagnostics work.

## 4. Verify persisted data

On the **repository** instance:

```sql
USE SQLManiakHealthHistory;
SELECT TOP (10) * FROM dhc.Run ORDER BY StartedUTC DESC;
SELECT TOP (20) * FROM dhc.vTempDBTrend ORDER BY StartedUTC DESC;
SELECT TOP (20) * FROM dhc.vDailyAlerts ORDER BY StartedUTC DESC;
SELECT COUNT_BIG(*) AS ResultBatches FROM dhc.ResultBatch;
```

Expect a new `dhc.Run` row and TempDB history if the complete PowerShell execution succeeded. **Creating the schema and running the standalone TempDB SQL does not itself write history.**

## 5. Logs, stop, cleanup

```powershell
docker compose -f compose.yaml logs --tail 80 sql-repository
docker compose -f compose.yaml logs --tail 80 sql-target
docker compose -f compose.yaml stop
docker compose -f compose.yaml down            # Keeps data volumes
docker compose -f compose.yaml down --volumes  # DANGER: permanently deletes the lab SQL data volumes
```

### Notes and limitations

- `mcr.microsoft.com/mssql/server:2022-latest` can change. Pin a tested image digest for a reproducible long-lived lab.
- Volume-based persistence does not replace database backups.
- `MSSQL_MEMORY_LIMIT_MB=2048` is a SQL Server memory configuration, not a hard Docker RAM limit.
- SQL Server on Linux cannot reproduce Windows cluster nodes, WSFC/FCI monitoring, or Windows service status.
- A DHC daily snapshot cannot reconstruct short-lived Version Store spikes. The separate 10-second TempDB Incident Recorder has not been implemented.
- The DHC v1.7 scripts have **not** been executed against a live SQL Server in this preparation environment. Validate before production usage.
