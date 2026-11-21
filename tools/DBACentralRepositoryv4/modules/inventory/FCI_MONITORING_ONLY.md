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

## One-off source-to-LAB integration (explicit, limited)

After Docker LAB schema verification, from PowerShell 7 on a workstation with approved integrated Windows access to `SQL32,1530`:

```powershell
.\modules\inventory\Test-FciOwnerToLab.ps1 -PreviewOnly
```

Preview reads source identity and `sys.dm_os_cluster_nodes` only; no repository connection or write.

When preview matches the intended `SQL32\SQLINS32` and two FCI nodes:

```powershell
.\modules\inventory\Test-FciOwnerToLab.ps1
```

The second command **only writes into the local Docker SQLManiak repository**, never into source/WSFC. It inserts a DELTA scan for the owner observation and records node/current-owner state. Multiple runs produce new owner observations. No failover occurs.

Verify in Docker repository:

```sql
SELECT TOP (10) ScanRunId,ServerInstance,ObservedUtc,PreviousOwner,CurrentOwner,IsChanged
FROM report.vFciOwnerHistory ORDER BY ScanRunId DESC;

SELECT i.ServerInstance,h.HostName,ih.IsCurrentOwner,ih.LastObservedUtc
FROM inventory.InstanceHost ih
JOIN inventory.Instance i ON i.InstanceId=ih.InstanceId
JOIN inventory.Host h ON h.HostId=ih.HostId
WHERE i.ServerInstance=N'SQL32\SQLINS32'
ORDER BY h.HostName;
```

An initial observation has `IsChanged=0` with no previous owner; a second observation with the same owner must also have `IsChanged=0`. Owner changes are only detected if an authorized administrator changes the FCI state independently and later monitoring observes it.
