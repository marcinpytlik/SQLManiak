# Debezium POC for SQLLab CDC

This folder extends the native SQL Server CDC lab with a minimal Debezium + Kafka test environment.

## Topology

```text
SQL64 (Hyper-V / SQLLab)
  SQL Server :1433
  CDC_Lab
      |
      | SQL Server CDC
      v
Docker Desktop
  Kafka (KRaft)
      ^
      |
  Kafka Connect + Debezium SQL Server Connector
      |
      v
Kafka topics
  sqllab.CDC_Lab.dbo.Customer
  sqllab.CDC_Lab.dbo.CustomerOrder
```

The SQL Server remains on the existing SQLLab Hyper-V network. Docker only runs Kafka and Kafka Connect/Debezium.

The lab assumes that containers can resolve `sql64` and connect to TCP/1433. This has already been verified in SQLLab with BusyBox (`ping`, `nc`, `nslookup`).

## Files

| File | Purpose |
|---|---|
| `.env.example` | Debezium image version |
| `docker-compose.yml` | Kafka KRaft + Kafka Connect/Debezium |
| `connector-sqlserver.template.json` | Connector template for `sql64:1433`, database `CDC_Lab` |
| `00_CreateDebeziumLogin.sql` | Creates SQL login/user and grants lab permissions |
| `01_Start.ps1` | Starts Kafka and Kafka Connect |
| `02_RegisterConnector.ps1` | Registers/updates the connector without storing the SQL password in Git |
| `03_Status.ps1` | Shows containers, Debezium plug-in and connector/task status |
| `04_ListTopics.ps1` | Lists Kafka topics |
| `05_Consume.ps1` | Reads Customer or CustomerOrder events |
| `06_TestChanges.sql` | Generates INSERT/UPDATE/DELETE operations |
| `99_StopAndCleanup.ps1` | Deletes connector and stops containers |

## 1. Prepare SQL login

Open `00_CreateDebeziumLogin.sql`, replace the example password and run the script against `sql64`.

Do not commit a real password to this repository.

The connector is intentionally configured with SQL authentication for the first POC. Kerberos/domain authentication can be tested as a separate step after the functional CDC pipeline works.

## 2. Start Kafka and Kafka Connect

From PowerShell:

```powershell
cd scripts\CDC-POC\Debezium
.\01_Start.ps1
```

The first run creates `.env` from `.env.example`.

Check containers:

```powershell
docker ps
```

Kafka Connect REST API is exposed on:

```text
http://localhost:8083
```

## 3. Register Debezium connector

Option A - prompt securely for the SQL password:

```powershell
.\02_RegisterConnector.ps1
```

Option B - set the password only in the current PowerShell process:

```powershell
$env:DEBEZIUM_SQL_PASSWORD = 'your-password'
.\02_RegisterConnector.ps1
Remove-Item Env:DEBEZIUM_SQL_PASSWORD
```

The script injects the password into the JSON only in memory and sends the configuration to Kafka Connect.

## 4. Check connector status

```powershell
.\03_Status.ps1
```

Expected state:

```text
connector: RUNNING
task 0:    RUNNING
```

For detailed logs:

```powershell
docker logs sqllab-debezium-connect --tail 200
```

## 5. List Kafka topics

```powershell
.\04_ListTopics.ps1
```

After the connector starts, expected data topics are:

```text
sqllab.CDC_Lab.dbo.Customer
sqllab.CDC_Lab.dbo.CustomerOrder
```

Debezium also creates an internal schema-history topic:

```text
schemahistory.sqllab.CDC_Lab
```

Do not consume or modify the schema-history topic as a business topic.

## 6. Watch events

Customer:

```powershell
.\05_Consume.ps1 -Table Customer -FromBeginning
```

CustomerOrder:

```powershell
.\05_Consume.ps1 -Table CustomerOrder -FromBeginning
```

Leave the consumer running and execute `06_TestChanges.sql` from SSMS.

Expected Debezium operation codes:

| op | Meaning |
|---|---|
| `r` | row read during snapshot |
| `c` | INSERT/create |
| `u` | UPDATE |
| `d` | DELETE |

For UPDATE events inspect both `before` and `after` payloads.

## Snapshot behavior

The connector uses:

```text
snapshot.mode=initial
```

On the first start, Debezium creates an initial snapshot and then continues streaming changes from SQL Server CDC.

Restarting the connector normally does not perform a new initial snapshot because Kafka Connect retains offsets.

Deleting the connector alone is not equivalent to a full re-initialization; internal offsets and schema history must be considered separately. See `CDC_Operational_Runbook.md` before intentionally resetting a connector.

## SQL Server connection settings

The connector uses:

```text
database.hostname=sql64
database.port=1433
database.names=CDC_Lab
```

For this isolated lab only:

```text
driver.encrypt=false
```

Production environments should use encryption with proper certificate validation instead of disabling TLS validation/encryption.

## Tables captured

```text
dbo.Customer
dbo.CustomerOrder
```

Configured by:

```text
table.include.list=dbo.Customer,dbo.CustomerOrder
```

Both tables must already have SQL Server CDC enabled before the connector starts.

## Basic fault tests

After the happy-path test succeeds, perform these tests one at a time:

1. Stop Kafka Connect, generate changes, start it again and verify backlog recovery.
2. Restart the SQL Server VM and verify connector recovery.
3. Restart Docker Desktop and verify offsets are retained.
4. Generate a transaction and roll it back; no committed business change should be emitted.
5. Generate many changes with the connector stopped, then verify catch-up.
6. Change the source schema using the procedures in `CDC_Operational_Runbook.md`.
7. Test a new CDC capture instance and connector restart.
8. Intentionally test CDC retention/LSN loss only in the lab.

## Stop the environment

Stop containers and remove the connector:

```powershell
.\99_StopAndCleanup.ps1
```

To also remove Docker volumes/state:

```powershell
.\99_StopAndCleanup.ps1 -RemoveVolumes
```

`-RemoveVolumes` is destructive and should be treated as a lab reset.

## Notes

- This environment is a POC, not a production Kafka deployment.
- Debezium container images are suitable for testing/evaluation; production deployments require separate security, HA, persistence and observability design.
- SQL authentication is used deliberately to separate CDC/Debezium testing from Kerberos troubleshooting.
- After this POC works, the next stage can replace SQL authentication with SQLLab domain/Kerberos authentication.
