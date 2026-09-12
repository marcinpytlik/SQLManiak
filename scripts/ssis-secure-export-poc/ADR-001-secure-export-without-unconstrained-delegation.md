# ADR-001: Secure export without Unconstrained Delegation

- **Status:** Accepted
- **Date:** 2026-09-12
- **Scope:** Windows application -> SQL Server -> background export -> SMB share
- **POC repository:** `scripts/ssis-secure-export-poc`

## 1. Context

A Windows application connects to SQL Server using Windows Authentication and requests generation of an export. The export must ultimately be written to a network share.

The original design relied on forwarding the application identity beyond SQL Server. In practice this leads toward the classic Windows double-hop/delegation problem and creates pressure to enable `Unconstrained Delegation` for an application identity.

That design has two major problems:

1. the application identity gains relevance outside the SQL Server security boundary,
2. compromise of a broadly delegated identity increases the blast radius.

The goal of this POC was therefore not to make delegation work, but to remove the requirement for delegation altogether.

## 2. Decision

The application identity ends its responsibility at SQL Server.

The application is allowed only to submit a business request through a stored procedure. SQL Server persists that request in a queue. A SQL Server Agent worker later processes the queued request under a separate technical identity represented by a SQL Agent Credential and Proxy.

The execution account, not the application account, receives access to the SMB share.

```text
Windows application
    |
    | Windows Authentication
    v
SQL Server
    |
    | dbo.usp_RequestExport
    v
ExportRequest queue
    |
    v
SQL Server Agent worker
    |
    | Credential / Proxy
    v
Dedicated execution account
    |
    | CmdExec in the POC
    | SSIS in the target environment
    v
Network share
```

The key architectural rule is:

```text
application identity != execution identity
```

## 3. Identity model

### Application identity

POC account:

```text
SQLLAB\poc-ssis-app
```

Responsibilities:

- authenticate to SQL Server,
- execute `dbo.usp_RequestExport`,
- submit business parameters such as `CustomerId` and `ReportDate`.

The application identity does **not** receive:

- direct CRUD permissions on `dbo.ExportRequest`,
- SQL Agent operator permissions,
- access to Agent Credential or Proxy objects,
- access to the SMB target,
- SSIS execution permissions,
- `Unconstrained Delegation`.

The original caller is recorded with `ORIGINAL_LOGIN()` for audit purposes.

### Execution identity

POC account:

```text
SQLLAB\poc-ssis-export
```

Responsibilities:

- execute the worker through SQL Server Agent Proxy,
- access only the internal worker interface in SQL Server,
- create output on the target SMB share.

The execution account receives only the permissions required for the export path.

## 4. Queue model

The application inserts requests indirectly through:

```text
dbo.usp_RequestExport
```

Requests are persisted in:

```text
dbo.ExportRequest
```

The processing lifecycle is:

```text
NEW -> PROCESSING -> DONE
        |
        +-> RETRY -> PROCESSING
        |
        +-> FAILED
```

The POC adds:

- attempt counter,
- maximum attempt count,
- next retry time,
- worker token,
- processing timestamps,
- output file path,
- error message.

## 5. Concurrency model

A worker claims one request atomically using locking semantics based on:

```sql
UPDLOCK, READPAST, ROWLOCK
```

This allows multiple workers to compete for available work while avoiding normal double-claim scenarios.

A `WorkerToken` is assigned during claim. Completion or failure updates must present the same token. This prevents a different worker from finalizing work it did not own.

For the POC:

```text
MaxAttempts = 3
RetryDelay  = 60 seconds
MaxItems    = 10 per worker invocation
Schedule    = every 1 minute
```

These values are operational defaults, not architectural requirements.

## 6. Idempotency and duplicate-output risk

The worker uses a deterministic output file name based on `RequestId`.

This reduces duplicate-output risk if a process writes the file and then fails before updating the queue row.

The design should still treat export execution as an idempotent operation wherever possible. For a production implementation, the exact overwrite/versioning policy must be explicitly defined.

## 7. POC execution path

The final POC path is:

```text
SQLLAB\poc-ssis-app
  -> dbo.usp_RequestExport
  -> dbo.ExportRequest
  -> SQL Agent Stage 5 Worker
  -> POC_Export_CmdExec_Proxy
  -> SQLLAB\poc-ssis-export
  -> PowerShell
  -> \\DC01\SSISLab$
```

The output file records the runtime identity. The successful test confirmed:

```text
WindowsIdentity=SQLLAB\poc-ssis-export
```

This proves that the application identity is not forwarded to the file server.

## 8. Why CmdExec is used in the POC

The target architecture is intended to support SSIS as the executor.

On the POC server `SQL64`:

- SQL Agent exposes the `SSIS` subsystem,
- SQL Agent successfully started an SSIS job step through the dedicated Proxy,
- the job history confirmed execution as `SQLLAB\poc-ssis-export`,
- however the server does not contain `Microsoft.SqlServer.ManagedDTS.dll`,
- SSDT / Visual Studio is not installed,
- SSISDB is not used in this lab.

Installing additional development/runtime components solely to build a disposable POC package was intentionally avoided.

Therefore Stage 4 and Stage 5 use `CmdExec` with PowerShell. This does not change the identity-separation decision being tested.

On a production server with the required SSIS runtime, the executor can be replaced:

```text
POC:
SQL Agent -> CmdExec Proxy -> execution account -> PowerShell -> SMB

Target:
SQL Agent -> SSIS Proxy -> execution account -> SSIS package -> SMB
```

The security boundary remains the same.

## 9. Why Unconstrained Delegation is not required

The design does not attempt to forward the authenticated application user's Kerberos identity from SQL Server to the file server.

Instead there are two independent authentication events:

```text
Application account -> SQL Server
Execution account   -> SMB share
```

SQL Server Agent obtains the execution identity from its Credential/Proxy configuration. The worker therefore accesses SMB using the dedicated execution account's own credentials.

Because caller identity is not forwarded to the SMB server, the design does not require `Unconstrained Delegation` for the application account.

KCD/RBCD would only become relevant if a future business requirement explicitly required the original caller identity to reach the downstream resource.

## 10. Security properties

The accepted design provides the following properties:

- least privilege for the application account,
- no application access to SMB,
- no direct application control of SQL Agent,
- no user-supplied UNC target,
- no secrets stored in repository scripts,
- separate execution identity,
- auditable original requester,
- bounded retry behavior,
- queue-based isolation between request submission and execution,
- no requirement for `Unconstrained Delegation`.

## 11. Share permissions

Only the dedicated execution identity requires write access to the export target.

For the POC, the target is:

```text
\\DC01\SSISLab$
```

The execution account receives only the required share and NTFS permissions. The application account is deliberately excluded.

In production the same principle applies: grant the technical execution account access only to the intended export location.

## 12. Consequences

### Positive

- removes the requirement to delegate the application identity,
- reduces blast radius,
- makes downstream access explicit and service-oriented,
- isolates application security from batch execution security,
- allows retry and asynchronous processing,
- makes failures observable in the queue,
- allows executor technology to change without changing the application contract.

### Trade-offs

- processing is asynchronous,
- SQL Agent becomes part of the execution path,
- queue lifecycle and retry policy must be monitored,
- stale `PROCESSING` requests need an operational recovery policy,
- execution credentials require lifecycle management,
- production SSIS deployment still needs its own deployment/runtime design.

## 13. Production recommendations

Before production rollout:

1. Run the worker under a managed service identity where practical, for example gMSA, instead of a conventional password-based domain account.
2. Define password/credential rotation if a standard domain account remains necessary.
3. Add monitoring for `FAILED`, excessive retries and stale `PROCESSING` rows.
4. Define a recovery policy for workers that terminate after claim but before completion.
5. Keep the export root fixed on the server side; do not accept arbitrary UNC paths from the application.
6. Validate SMB share and NTFS ACLs independently.
7. Define retention and cleanup for output files and queue history.
8. If SSIS is used in production, deploy the package using the organization's supported SSIS deployment model and assign only the required Proxy/subsystem permissions.
9. Test failover behavior if SQL Agent runs on an FCI/HA platform.
10. Document ownership, support responsibilities and emergency recovery procedures.

## 14. Rejected alternatives

### Unconstrained Delegation

Rejected because it extends trust beyond what the business requirement needs and unnecessarily increases the security exposure of the application identity.

### Direct SMB access from the application

Rejected because it couples the application to file-share permissions, path management and downstream authentication.

### Direct SQL Agent execution by the application

Rejected because the application should submit business requests, not control infrastructure-level scheduling/execution objects.

### Arbitrary UNC supplied by the caller

Rejected because it would allow the caller to influence the downstream security boundary and create an unnecessary exfiltration/misconfiguration risk.

## 15. Validation evidence

The POC successfully validated the following stages:

```text
Stage 1  Queue and request procedure
Stage 2  Restricted application permissions
Stage 3  Dedicated export account, Credential, Proxy and SMB access
Stage 4  SQL Agent Proxy execution under SQLLAB\poc-ssis-export
Stage 5  End-to-end queue worker with retry/concurrency handling
```

The decisive observation from SQL Agent history and the generated output was that execution occurred under:

```text
SQLLAB\poc-ssis-export
```

not under the application identity.

## 16. Final architecture

```text
+---------------------------+
| Windows Application       |
| SQLLAB\poc-ssis-app       |
+-------------+-------------+
              |
              | Windows Authentication
              | EXEC dbo.usp_RequestExport
              v
+---------------------------+
| SQL Server                |
| SSIS_Delegation_Lab       |
| dbo.ExportRequest         |
+-------------+-------------+
              |
              | asynchronous dequeue
              v
+---------------------------+
| SQL Server Agent          |
| Stage 5 Worker            |
+-------------+-------------+
              |
              | Credential / Proxy
              v
+---------------------------+
| SQLLAB\poc-ssis-export    |
| dedicated execution acct  |
+-------------+-------------+
              |
              | authenticated SMB access
              v
+---------------------------+
| Network Share             |
| \\DC01\SSISLab$          |
+---------------------------+
```

## 17. Decision summary

The POC demonstrates that the required export workflow can be implemented without forwarding the application identity to downstream resources.

The accepted pattern is therefore:

```text
submit request -> persist queue -> execute asynchronously under a dedicated identity
```

`Unconstrained Delegation` is not part of the target architecture.