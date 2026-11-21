# FCI ownership monitoring — strictly observation only

**Do not initiate failover.** The customer's FCI role movement is an exclusively manual administrative operation. SQLManiak never calls Move-ClusterGroup, Switch-SqlAvailabilityGroup, ALTER AVAILABILITY GROUP FAILOVER, Start/Stop-ClusterGroup, cluster.exe or restart cmdlets.

## Data path

Source SQL Server: `sys.dm_os_cluster_nodes` read-only -> PowerShell collector -> central DB `inventory.Host`, `inventory.InstanceHost`, `inventory.FciOwnerObservation`.

Each completed FCI collection updates membership/current-owner state and records the observed owner per `ScanRunId`. The first observation is a **baseline**, not a failover. Subsequent observations set `IsChanged=1` only when the owner differs from the previously observed owner.

`ObservedUtc` is when the collector recorded the owner, **not** the exact time of administrative failover. No automatic failover operations are provided.

## Safe installation and validation in LAB

```powershell
git pull --ff-only
cd tools/DBACentralRepositoryv4
.\docker\Initialize-Repository.ps1
.\docker\Test-Inventory.ps1 -Persist
```

The Docker standalone has `IsClustered=0`, so no FCI owner observation is written there. Inspect objects in central repository:

```sql
SELECT OBJECT_ID(N'inventory.FciOwnerObservation',N'U') AS OwnerTableId,
       OBJECT_ID(N'inventory.usp_RecordFciObservation',N'P') AS RecordingProcId;
SELECT TOP (20) * FROM report.vFciOwnerHistory ORDER BY ObservedUtc DESC;
```

Both object IDs should be non-null; history should be empty for standalone-only collection.

## FCI source check — no writes

For SQL Server instance `SQL32\SQLINS32` via `SQL32,1530`:

```powershell
.\modules\inventory\Test-InventoryReadiness.ps1 -ServerInstance 'SQL32,1530'
```

Or read-only SQL:

```sql
SELECT @@SERVERNAME AS SqlInstance,
       CONVERT(nvarchar(128),SERVERPROPERTY('ComputerNamePhysicalNetBIOS')) AS CurrentPhysicalNode;
SELECT NodeName,status_description AS NodeStatus,is_current_owner AS IsCurrentOwner
FROM sys.dm_os_cluster_nodes ORDER BY NodeName;
```

Expected from the last observation: `procjon1` current owner, `procjon2` other node; **do not assert it remains so without new evidence**.

## Future controlled connection

The next integration test will use *read-only access* to FCI and a **separate non-production repository**, with explicitly approved credentials. No central production writes should be attempted before a service-account least-privilege review, retention plan and HA data verification.

Avoid reusing the Docker SA account for a production source. The collector supports separate SourceCredential and RepositoryCredential parameters.
