# DHC v1.7 — SQL-only setup of a monitored SQL Server (source)

Use `38_Configure-DHC-Source-AllInOne.sql` in **SSMS**, on **each monitored SQL Server 2022+ instance**, as an authorized deployment DBA. No PowerShell is used in the installation phase. This script provisions the **source** login and permissions; the central Repository setup is a different script: `37_Install-DHC-Repository-AllInOne.sql`.

## Steps

1. Confirm `SELECT @@SERVERNAME,SERVERPROPERTY('ProductVersion');` on the **intended** source (FCI: SQL instance name, not physical node name).
2. Open a private, untracked copy of the installer outside Git and replace `@ExpectedServer` with the literal `@@SERVERNAME` result.
3. If creating `dhc_source_collector`, set a *unique, strong* `@Password` in that **local** copy. Do not commit actual passwords. On reruns, if the SQL login exists, the password placeholder may remain unchanged.
4. Leave `@GrantAlterTrace=0` by default. Only enable after separate security review if the current DHC v1.5 autogrowth mechanism requires it. Disabling the switch on a rerun does **not** revoke an earlier grant.
5. Run the script from SSMS, then inspect the verification resultsets: server, no sysadmin membership, server permissions, msdb roles.
6. Connect as `dhc_source_collector` and run the existing DHC v1.5/TempDB diagnostic read-only collection before enabling the production schedule. Permissions on special local objects and the underlying `ERRORLOG` / autogrowth operations may need a separately reviewed adjustment.
7. Configure a *separate credential* for **source** connections in the DHC runner; the Repository writer is `dhc_repository_collector` and the Grafana reader is `dhc_grafana_reader`. Never reuse these accounts or grant sysadmin to the source collector.

## Objects and grants

- SQL login/user: `dhc_source_collector` and `msdb.dhc_source_collector`
- SQL2022+ server permissions: `VIEW SERVER PERFORMANCE STATE`, `VIEW SERVER SECURITY STATE`, `VIEW ANY ERROR LOG`, `VIEW ANY DEFINITION` (instance-wide metadata visibility; review before production)
- `msdb` membership: `SQLAgentReaderRole` and custom `dhc_agent_history_reader` (SELECT on `sysjobschedules`, `sysjobhistory`, `sysjobs`, `sysjobactivity`, `sysschedules`; EXECUTE on `dbo.agent_datetime`)
- `ALTER TRACE` only through optional `dhc_autogrowth_reader` server role; this is a broad permission and requires bank authorization.

## Limitations and operational requirements

- Does **not** create database `SQLManiakHealthHistory`, Repository objects, monitored-instance inventory rows, collector runtime, job/task scheduler, Grafana, or alerts.
- Does not change user databases, FCI ownership, SQL Agent service state, recovery models or any existing passwords.
- Uses SQL Server 2022+ permission model. SQL Server 2019/2016 requires a separately validated edition and permission mapping.
- Run as authorized DBA. Re-executing the installer adds missing grants/memberships but does not reset passwords or revoke old permissions. This is not a transactional all-or-nothing deployment across server and msdb; preserve change records and review any partial failure.
- Keep secrets out of Git history, SQL logs, query capture and saved SSMS script copies. Bank identity policies may prefer Windows authentication/gMSA to SQL logins; this script specifically covers SQL authentication as requested.
