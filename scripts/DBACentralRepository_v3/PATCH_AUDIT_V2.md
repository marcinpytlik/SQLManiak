# Patch Audit v2 – integracja z DBACentralRepository v3

## Zasada architektoniczna

Moduł nie tworzy drugiego zestawu snapshotów w schemacie `patch`.
Dane techniczne pozostają w istniejących domenach:

- `patch.InstanceBuildHistory` – build SQL Server,
- `db.DatabaseSnapshot` – stan i konfiguracja baz,
- `backup.BackupHistory` – historia backupów,
- `ha.ReplicaSnapshot` / `ha.DatabaseReplicaSnapshot` – AG,
- `maintenance.SuspectPageSnapshot` – suspect pages,
- `config.LinkedServerSnapshot` – Linked Servers,
- `config.TraceFlagSnapshot` – trace flags,
- `config.QueryStoreSnapshot` – szczegółowy stan Query Store (dodane w v2),
- `patch.CodeRiskSnapshot` – patch-specyficzne ryzyka w kodzie, obecnie `SESSION_CONTEXT` (dodane w v2).

Schemat `patch` otrzymuje tylko warstwę procesu patchowania:

- `patch.PatchCycle` – jedno okno/change dla jednej instancji,
- `patch.PatchCyclePhase` – PRE lub POST wskazujące istniejący `dbo.ScanRun`,
- `patch.PatchFinding` – wynik oceny danego PRE/POST,
- `patch.vPatchCycleHistory` – historia PRE/POST,
- `patch.usp_StartPatchCycle`,
- `patch.usp_RegisterPatchPhase`,
- `patch.usp_ComparePatchCycle`,
- `patch.usp_LatestPatchStatus`.

## Przykład

```sql
DECLARE @PatchCycleId bigint;

EXEC patch.usp_StartPatchCycle
    @ServerInstance = N'SQLPROD01',
    @TargetVersion = N'16.0.4265.3',
    @TargetReleaseName = N'SQL Server 2022 CU26',
    @ChangeReference = N'CHG-2026-0001',
    @PatchCycleId = @PatchCycleId OUTPUT;

SELECT @PatchCycleId AS PatchCycleId;
```

Po wykonaniu collectora zapamiętaj zwrócony `ScanRunId`, a następnie:

```sql
EXEC patch.usp_RegisterPatchPhase
    @PatchCycleId = 1,
    @AuditPhase = 'PRE',
    @ScanRunId = 12345;
```

Po patchingu wykonaj collector ponownie i zarejestruj POST:

```sql
EXEC patch.usp_RegisterPatchPhase
    @PatchCycleId = 1,
    @AuditPhase = 'POST',
    @ScanRunId = 12346;

EXEC patch.usp_ComparePatchCycle
    @PatchCycleId = 1;
```

## Co zostało usunięte względem pierwotnego PatchAudit v2

Nie tworzymy już duplikatów:

- `patch.DatabaseSnapshot`,
- `patch.BackupSnapshot`,
- `patch.LinkedServerSnapshot`,
- `patch.AGReplicaSnapshot`,
- `patch.AGDatabaseSnapshot`,
- `patch.QueryStoreSnapshot`,
- `patch.SuspectPageSnapshot`.

Te dane mają już swoje właściwe schematy domenowe w DBACentralRepository.
