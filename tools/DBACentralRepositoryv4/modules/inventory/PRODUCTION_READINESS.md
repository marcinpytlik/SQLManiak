# SQLManiak — Inventory v4.2 Production Readiness

Status: **implementation for LAB verification**. Do not deploy to production before Windows/FCI privilege and performance tests.

## Scope and safety

- Default identity: Windows Integrated Security (no `-Credential`).
- Readiness script is read-only: no logins, grants, SQL Agent jobs, DDL or repository writes.
- FCI/AG queries are active only when features are enabled according to `SERVERPROPERTY`.
- Volume metadata may require `VIEW SERVER PERFORMANCE STATE` in SQL Server 2022; service state may require `VIEW SERVER SECURITY STATE`. SQL Server 2016/2019 have different requirements.
- SQL Agent all-jobs visibility requires checking the appropriate `msdb` role, usually `SQLAgentReaderRole`; a successful empty result from a metadata query does **not** prove full visibility.
- For every database, collection of schema and permissions depends on metadata visibility and database access. Missing database access can cause silent omissions; compare total DB count vs inspected DB count.
- Avoid placing encrypted passwords/credentials in snapshots. Validate sensitive categories before sharing reports.
- **Important:** Readiness query success alone does not guarantee full visibility. Production account must run the full collector dry-run and compare counts against a privileged baseline.

## 1. Start with Docker LAB

```powershell
cd C:\Users\blad\Documents\GitHub\SQLManiak
git pull --ff-only
cd .\tools\DBACentralRepositoryv4
.\docker\Initialize-Repository.ps1
```

The installer now executes `05_Retention_Preview.sql` without removing any records.

```powershell
.\modules\inventory\Measure-Inventory.ps1 -ConfigPath .\config\servers.local.json -Repetitions 3
```

**Note:** local Docker lab uses SQL Authentication; the generic `Measure-Inventory.ps1` defaults to Windows authentication. To benchmark Docker use the credential switch, e.g. in a shell with the LAB credential securely prepared:

```powershell
$envVals = @{}
Get-Content .\docker\.env | ForEach-Object { if ($_ -match '^([A-Z_]+)=(.*)$') { $envVals[$Matches[1]] = $Matches[2] } }
$labCredential = [pscredential]::new('sa',(ConvertTo-SecureString $envVals.TARGET_SA_PASSWORD -AsPlainText -Force))
.\modules\inventory\Measure-Inventory.ps1 -ConfigPath .\config\servers.local.json -SourceCredential $labCredential -Repetitions 3
```

Run an explicit readiness check in Docker using LAB credentials:

```powershell
.\modules\inventory\Test-InventoryReadiness.ps1 -ServerInstance '127.0.0.1,15434' -Credential $labCredential -TrustServerCertificate
```

## 2. Windows/FCI LAB (do not point at production yet)

```powershell
.\modules\inventory\Test-InventoryReadiness.ps1 -ServerInstance 'SQL-VNN\INSTANCE' -CsvPath '.\readiness-fci.csv'
```

Execute as the intended service identity with Integrated Security. Use proper SQL TLS certificates; do not add `-TrustServerCertificate` for production as a default.

Validate:
1. Physical node (`ComputerNamePhysicalNetBIOS`) and SQL VNN (`MachineName`) differ appropriately;
2. `sys.dm_os_cluster_nodes` returns members and exactly one current owner;
3. metadata visibility for all databases, especially `msdb`, and all expected Agent jobs;
4. dry-run is non-mutating and finishes within agreed maintenance window;
5. failover is only observed, **never initiated** by the collector.

## 3. Retention preview only

```sql
EXEC inventory.usp_RetentionPreview @KeepDays=90;
```

No deletion functionality is implemented. Review history requirements, required retention for investigations, and count of dependent rows before designing an approved purge with small committed batches. Preserve most recent complete baseline per instance and handle `ChangeEvent` references in correct dependency order.

## 4. Production gates

- DBA-reviewed least-privilege configuration for 2016/2019/2022 separately (server DMV permissions differ).
- Two complete dry-runs on Windows FCI with no permission failures.
- Coverage review: number of databases, Agent jobs, security principals and databases skipped.
- Throughput test against a high-object-count non-production instance; memory and repository growth measured.
- Separate account to write snapshots in repository; do not grant source account repository DDL/admin.
- Restore test and retention approval; only then schedule ongoing Inventory.
