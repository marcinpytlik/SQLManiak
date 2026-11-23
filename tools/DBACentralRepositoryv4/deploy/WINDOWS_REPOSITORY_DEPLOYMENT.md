# DBACentralRepositoryv4 — Windows SQL Server deployment

Docker was only a functional lab. For Windows/FCI integration tests, install the repository on a **separate, explicitly designated Windows SQL Server instance** reachable from the workstation and source FCI. Do **not** install the repository in the production FCI being monitored.

## Preconditions

- Choose a noncritical Windows SQL Server 2016+ repository instance, hostname/instance/port, and confirm permission to create a dedicated database.
- Backup/restore and disk space policy for repository must be approved before regular use.
- PowerShell 7 and the SqlServer PowerShell module on the administration workstation.
- Run PowerShell as an approved Windows administrator/DBA identity. Installer uses Windows Integrated Authentication. No passwords are stored in repo.
- Verify SQL certificate trust; use `-TrustServerCertificate` only under an explicit environment-specific security decision.
- The deployment creates/updates only `DBACentralRepositoryv4` and related objects. It does not schedule SQL Agent jobs or run collectors.
- Initial install is a fresh DB. For an existing database the installer refuses unless `-AllowExisting` is explicitly passed.

## Step 1 — preflight, read-only

```powershell
cd C:\Users\blad\Documents\GitHub\SQLManiak
git pull --ff-only
cd .\tools\DBACentralRepositoryv4
.\deploy\Install-RepositoryWindows.ps1 -ServerInstance 'YOUR-REPOSITORY-SQL\INSTANCE'
```

Inspect target server, edition/build, FCI flag and whether the database already exists. Do not pass `-Install` until the target identity and repository instance are verified. If you have an endpoint using a fixed TCP port, use e.g. `'YOUR-REPOSITORY-SQL,1433'` instead.

## Step 2 — explicitly install on designated repository

```powershell
.\deploy\Install-RepositoryWindows.ps1 -ServerInstance 'YOUR-REPOSITORY-SQL\INSTANCE' -Install
```

Seven SQL files are installed in dependency order (00 through 06). For an already-existing v4 repository, carefully verify it and append `-AllowExisting`. Schema scripts are designed to be repeatable but should still be reviewed and backed up before reapplying on an established system.

## Step 3 — verify the installation (repository only)

```sql
USE [DBACentralRepositoryv4];
GO
SELECT DB_NAME() AS DatabaseName,
       OBJECT_ID(N'inventory.ScanRun',N'U') AS ScanRunTableId,
       OBJECT_ID(N'inventory.FciOwnerObservation',N'U') AS FciOwnerTableId,
       OBJECT_ID(N'inventory.usp_RecordFciObservation',N'P') AS RecordingProcId;
SELECT TOP(20) *
FROM report.vFciOwnerHistory
ORDER BY ScanRunId DESC;
```

Expect non-NULL IDs and empty FCI history before the first actual observation.

## Next: integrated read-only FCI observation

First use the already-tested `Test-InventoryReadiness.ps1 -ServerInstance 'SQL32,1530'` on the source with Windows Authentication. The full collector and the current `Test-FciOwnerToLab.ps1` are **not** the Windows repository deployment workflow; the latter is intentionally hardcoded to Docker LAB. A dedicated source-FCI -> Windows-repository observation test should be used next, with separately scoped write privileges in repository and **read-only** permissions on source.

No automatic FCI failover or WSFC role movement is ever permitted.
