using System.Collections.Concurrent;
using System.Data;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: false)
    .Build();

var settings = configuration
    .GetSection("SqlLockSimulator")
    .Get<SimulatorSettings>()
    ?? throw new InvalidOperationException("Brak sekcji SqlLockSimulator.");

ValidateSettings(settings);

var runId = Guid.NewGuid();

Console.WriteLine("============================================================");
Console.WriteLine("SQL Lock Simulator V3");
Console.WriteLine($"RunId                   : {runId}");
Console.WriteLine($"Start                   : {DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}");
Console.WriteLine($"Scenario                : {settings.Scenario}");
Console.WriteLine($"TestMode                : {settings.TestMode}");
Console.WriteLine($"ResolvedLockHint        : {ResolveLockHint(settings.TestMode)}");
Console.WriteLine($"WorkerCount             : {settings.WorkerCount}");
Console.WriteLine($"IterationsPerWorker     : {settings.IterationsPerWorker}");
Console.WriteLine($"EnableDmvMonitor        : {settings.EnableDmvMonitor}");
Console.WriteLine($"EnableLockMonitor       : {settings.EnableLockMonitor}");
Console.WriteLine($"EnableSqlLogging        : {settings.EnableSqlLogging}");
Console.WriteLine("============================================================");

if (settings.CreateDemoTableIfMissing)
{
    await EnsureDemoTableAsync(settings);
}

if (settings.CreateLogTableIfMissing)
{
    await EnsureLogTableAsync(settings);
}

using var startGate = new ManualResetEventSlim(false);
using var cts = new CancellationTokenSource();

var workerSpids = new ConcurrentDictionary<int, int>();

Task? dmvMonitorTask = null;
if (settings.EnableDmvMonitor)
{
    dmvMonitorTask = Task.Run(() => RunDmvMonitorAsync(runId, settings, workerSpids, cts.Token));
}

Task? lockMonitorTask = null;
if (settings.EnableLockMonitor)
{
    lockMonitorTask = Task.Run(() => RunLockMonitorAsync(runId, settings, workerSpids, cts.Token));
}

var workerTasks = new List<Task>();

for (int i = 1; i <= settings.WorkerCount; i++)
{
    var workerId = i;
    workerTasks.Add(Task.Run(() => RunWorkerAsync(runId, workerId, settings, startGate, workerSpids, cts.Token)));
}

Console.WriteLine($"Workery gotowe. Start wspólny za {settings.StartDelayMs} ms...");
await Task.Delay(settings.StartDelayMs);
startGate.Set();

await Task.WhenAll(workerTasks);

cts.Cancel();

foreach (var monitor in new[] { dmvMonitorTask, lockMonitorTask }.Where(x => x is not null))
{
    try
    {
        await monitor!;
    }
    catch (OperationCanceledException)
    {
        // expected
    }
}

Console.WriteLine($"Koniec: {DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}");

static async Task RunWorkerAsync(
    Guid runId,
    int workerId,
    SimulatorSettings settings,
    ManualResetEventSlim startGate,
    ConcurrentDictionary<int, int> workerSpids,
    CancellationToken cancellationToken)
{
    startGate.Wait(cancellationToken);

    var rng = new Random(unchecked(Environment.TickCount * 31 + workerId));

    for (int iteration = 1; iteration <= settings.IterationsPerWorker; iteration++)
    {
        SqlConnection? connection = null;
        SqlTransaction? transaction = null;
        int? spid = null;

        var startedAt = DateTime.Now;
        var targetId = ResolveTargetId(workerId, iteration, settings, rng);
        var lockHint = ResolveLockHint(settings.TestMode);

        try
        {
            connection = new SqlConnection(settings.ConnectionString);
            await connection.OpenAsync(cancellationToken);

            spid = await GetSpidAsync(connection, settings.CommandTimeoutSeconds, cancellationToken);
            workerSpids[workerId] = spid.Value;

            await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO",
                $"OPEN | scenario={settings.Scenario} | targetId={targetId}", cancellationToken);

            Log(workerId, spid, $"ITER {iteration}/{settings.IterationsPerWorker} | OPEN | targetId={targetId}");

            transaction = (SqlTransaction)await connection.BeginTransactionAsync(IsolationLevel.ReadCommitted, cancellationToken);
            await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", "BEGIN TRAN", cancellationToken);
            Log(workerId, spid, $"ITER {iteration} | BEGIN TRAN");

            switch (Normalize(settings.Scenario))
            {
                case "CONTENTION":
                case "QUEUE":
                    await ExecuteStandardScenarioAsync(
                        runId, workerId, iteration, settings, targetId, lockHint,
                        connection, transaction, spid.Value, cancellationToken);
                    break;

                case "DEADLOCK":
                    await ExecuteDeadlockScenarioAsync(
                        runId, workerId, iteration, settings,
                        connection, transaction, spid.Value, cancellationToken);
                    break;

                default:
                    throw new InvalidOperationException($"Nieznany Scenario: {settings.Scenario}");
            }

            await transaction.CommitAsync(cancellationToken);

            var elapsedMs = (long)(DateTime.Now - startedAt).TotalMilliseconds;
            await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO",
                $"COMMIT | elapsed_ms={elapsedMs}", cancellationToken);

            Log(workerId, spid, $"ITER {iteration} | COMMIT | elapsed={elapsedMs:N0} ms");
        }
        catch (OperationCanceledException)
        {
            await LogToSqlAsync(runId, settings, workerId, iteration, spid, "WARN", "CANCELLED", CancellationToken.None);
            Log(workerId, spid, $"ITER {iteration} | CANCELLED");
            throw;
        }
        catch (Exception ex)
        {
            try
            {
                if (transaction is not null && transaction.Connection is not null)
                {
                    await transaction.RollbackAsync(CancellationToken.None);
                    await LogToSqlAsync(runId, settings, workerId, iteration, spid, "WARN", "ROLLBACK", CancellationToken.None);
                    Log(workerId, spid, $"ITER {iteration} | ROLLBACK");
                }
            }
            catch (Exception rollbackEx)
            {
                await LogToSqlAsync(runId, settings, workerId, iteration, spid, "ERROR",
                    $"ROLLBACK ERROR: {Trim(rollbackEx.Message, 3500)}", CancellationToken.None);
                Log(workerId, spid, $"ITER {iteration} | ROLLBACK ERROR: {rollbackEx.Message}");
            }

            await LogToSqlAsync(runId, settings, workerId, iteration, spid, "ERROR",
                $"ERROR: {Trim(ex.Message, 3500)}", CancellationToken.None);

            Log(workerId, spid, $"ITER {iteration} | ERROR: {ex.Message}");
        }
        finally
        {
            if (transaction is not null)
                await transaction.DisposeAsync();

            if (connection is not null)
                await connection.DisposeAsync();
        }

        if (iteration < settings.IterationsPerWorker && settings.DelayBetweenIterationsMs > 0)
        {
            await Task.Delay(settings.DelayBetweenIterationsMs, cancellationToken);
        }
    }
}

static async Task ExecuteStandardScenarioAsync(
    Guid runId,
    int workerId,
    int iteration,
    SimulatorSettings settings,
    int targetId,
    string lockHint,
    SqlConnection connection,
    SqlTransaction transaction,
    int spid,
    CancellationToken cancellationToken)
{
    var selectSql = lockHint.Length == 0
        ? $"""
           SELECT Id, StatusName, Notes
           FROM {settings.TargetTable}
           WHERE Id = @Id;
           """
        : $"""
           SELECT Id, StatusName, Notes
           FROM {settings.TargetTable} WITH ({lockHint})
           WHERE Id = @Id;
           """;

    await using (var selectCmd = new SqlCommand(selectSql, connection, transaction))
    {
        selectCmd.CommandTimeout = settings.CommandTimeoutSeconds;
        selectCmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = targetId });

        await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", $"SELECT start | targetId={targetId}", cancellationToken);
        Log(workerId, spid, $"ITER {iteration} | SELECT...");

        await using var reader = await selectCmd.ExecuteReaderAsync(cancellationToken);

        var found = false;
        while (await reader.ReadAsync(cancellationToken))
        {
            found = true;
            var id = reader.GetInt32(0);
            var status = reader.GetString(1);
            var notes = reader.IsDBNull(2) ? null : reader.GetString(2);

            var rowMsg = $"ROW -> Id={id}, Status={status}, Notes={notes ?? "<NULL>"}";
            await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", rowMsg, cancellationToken);
            Log(workerId, spid, $"ITER {iteration} | {rowMsg}");
        }

        if (!found)
        {
            await LogToSqlAsync(runId, settings, workerId, iteration, spid, "WARN", "SELECT returned 0 rows", cancellationToken);
            Log(workerId, spid, $"ITER {iteration} | SELECT returned 0 rows");
        }
    }

    await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", $"HOLD {settings.HoldSeconds}s", cancellationToken);
    Log(workerId, spid, $"ITER {iteration} | HOLD {settings.HoldSeconds}s");
    await Task.Delay(TimeSpan.FromSeconds(settings.HoldSeconds), cancellationToken);

    if (settings.DoUpdate)
    {
        if (settings.DelayBetweenSelectAndUpdateMs > 0)
        {
            await Task.Delay(settings.DelayBetweenSelectAndUpdateMs, cancellationToken);
        }

        var updateSql = $"""
            UPDATE {settings.TargetTable}
            SET Notes = CONCAT(
                ISNULL(Notes, ''),
                CASE WHEN Notes IS NULL OR Notes = '' THEN '' ELSE ' | ' END,
                'worker ', @WorkerId, ' iter ', @Iteration, ' at ',
                CONVERT(varchar(23), GETDATE(), 121)
            )
            WHERE Id = @Id;
            """;

        await using var updateCmd = new SqlCommand(updateSql, connection, transaction);
        updateCmd.CommandTimeout = settings.CommandTimeoutSeconds;
        updateCmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = targetId });
        updateCmd.Parameters.Add(new SqlParameter("@WorkerId", SqlDbType.Int) { Value = workerId });
        updateCmd.Parameters.Add(new SqlParameter("@Iteration", SqlDbType.Int) { Value = iteration });

        await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", $"UPDATE start | targetId={targetId}", cancellationToken);
        Log(workerId, spid, $"ITER {iteration} | UPDATE...");

        var rows = await updateCmd.ExecuteNonQueryAsync(cancellationToken);

        await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", $"UPDATE rows={rows}", cancellationToken);
        Log(workerId, spid, $"ITER {iteration} | UPDATE rows={rows}");
    }
}

static async Task ExecuteDeadlockScenarioAsync(
    Guid runId,
    int workerId,
    int iteration,
    SimulatorSettings settings,
    SqlConnection connection,
    SqlTransaction transaction,
    int spid,
    CancellationToken cancellationToken)
{
    var firstId = workerId % 2 == 1 ? 1 : 2;
    var secondId = workerId % 2 == 1 ? 2 : 1;

    var lockHint = "UPDLOCK, ROWLOCK";

    async Task SelectForLockAsync(int id, string phase)
    {
        var sql = $"""
            SELECT Id, StatusName, Notes
            FROM {settings.TargetTable} WITH ({lockHint})
            WHERE Id = @Id;
            """;

        await using var cmd = new SqlCommand(sql, connection, transaction);
        cmd.CommandTimeout = settings.CommandTimeoutSeconds;
        cmd.Parameters.Add(new SqlParameter("@Id", SqlDbType.Int) { Value = id });

        await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", $"{phase} lock start | Id={id}", cancellationToken);
        Log(workerId, spid, $"ITER {iteration} | {phase} lock Id={id}");

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);
        while (await reader.ReadAsync(cancellationToken))
        {
            // samo odczytanie wystarczy do założenia locka
        }
    }

    await SelectForLockAsync(firstId, "FIRST");
    await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", $"HOLD before second lock {settings.HoldSeconds}s", cancellationToken);
    Log(workerId, spid, $"ITER {iteration} | HOLD before second lock {settings.HoldSeconds}s");

    await Task.Delay(TimeSpan.FromSeconds(settings.HoldSeconds), cancellationToken);

    // tu najczęściej zaczyna się cyrk z deadlockiem
    await SelectForLockAsync(secondId, "SECOND");

    if (settings.DoUpdate)
    {
        var sql = $"""
            UPDATE {settings.TargetTable}
            SET Notes = CONCAT(
                ISNULL(Notes, ''),
                CASE WHEN Notes IS NULL OR Notes = '' THEN '' ELSE ' | ' END,
                'deadlock worker ', @WorkerId, ' iter ', @Iteration, ' at ',
                CONVERT(varchar(23), GETDATE(), 121)
            )
            WHERE Id IN (@FirstId, @SecondId);
            """;

        await using var cmd = new SqlCommand(sql, connection, transaction);
        cmd.CommandTimeout = settings.CommandTimeoutSeconds;
        cmd.Parameters.Add(new SqlParameter("@WorkerId", SqlDbType.Int) { Value = workerId });
        cmd.Parameters.Add(new SqlParameter("@Iteration", SqlDbType.Int) { Value = iteration });
        cmd.Parameters.Add(new SqlParameter("@FirstId", SqlDbType.Int) { Value = firstId });
        cmd.Parameters.Add(new SqlParameter("@SecondId", SqlDbType.Int) { Value = secondId });

        await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", "DEADLOCK scenario UPDATE start", cancellationToken);
        Log(workerId, spid, $"ITER {iteration} | DEADLOCK UPDATE...");

        var rows = await cmd.ExecuteNonQueryAsync(cancellationToken);

        await LogToSqlAsync(runId, settings, workerId, iteration, spid, "INFO", $"DEADLOCK UPDATE rows={rows}", cancellationToken);
        Log(workerId, spid, $"ITER {iteration} | DEADLOCK UPDATE rows={rows}");
    }
}

static async Task RunDmvMonitorAsync(
    Guid runId,
    SimulatorSettings settings,
    ConcurrentDictionary<int, int> workerSpids,
    CancellationToken cancellationToken)
{
    while (!cancellationToken.IsCancellationRequested)
    {
        try
        {
            var spids = workerSpids.Values.Distinct().OrderBy(x => x).ToArray();
            if (spids.Length == 0)
            {
                await Task.Delay(settings.DmvMonitorIntervalMs, cancellationToken);
                continue;
            }

            var inList = string.Join(", ", spids);

            await using var connection = new SqlConnection(settings.ConnectionString);
            await connection.OpenAsync(cancellationToken);

            var sql = $"""
                SELECT
                    r.session_id,
                    r.blocking_session_id,
                    r.status,
                    r.command,
                    r.wait_type,
                    r.wait_time,
                    r.last_wait_type,
                    DB_NAME(r.database_id) AS database_name,
                    LEFT(REPLACE(REPLACE(t.text, CHAR(13), ' '), CHAR(10), ' '), 300) AS sql_text
                FROM sys.dm_exec_requests r
                CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
                WHERE r.session_id IN ({inList})
                   OR r.blocking_session_id IN ({inList})
                ORDER BY r.session_id;
                """;

            await using var cmd = new SqlCommand(sql, connection)
            {
                CommandTimeout = settings.CommandTimeoutSeconds
            };

            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

            var any = false;
            while (await reader.ReadAsync(cancellationToken))
            {
                any = true;

                var msg =
                    $"REQ session={reader.GetInt16(0)} " +
                    $"block_by={reader.GetInt16(1)} " +
                    $"status={reader.GetString(2)} " +
                    $"cmd={reader.GetString(3)} " +
                    $"wait={GetNullableString(reader, 4) ?? "-"} " +
                    $"wait_ms={reader.GetInt32(5)} " +
                    $"last_wait={GetNullableString(reader, 6) ?? "-"} " +
                    $"db={GetNullableString(reader, 7) ?? "-"} " +
                    $"sql={GetNullableString(reader, 8) ?? "-"}";

                Console.WriteLine($"[MON-REQ {DateTime.Now:HH:mm:ss.fff}] {msg}");

                if (settings.EnableSqlLogging)
                {
                    await LogMonitorToSqlAsync(runId, settings, "REQ", msg, cancellationToken);
                }
            }

            if (!any)
            {
                var msg = "brak aktywnych requestów workerów";
                Console.WriteLine($"[MON-REQ {DateTime.Now:HH:mm:ss.fff}] {msg}");

                if (settings.EnableSqlLogging)
                {
                    await LogMonitorToSqlAsync(runId, settings, "REQ", msg, cancellationToken);
                }
            }

            await Task.Delay(settings.DmvMonitorIntervalMs, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var msg = $"monitor req error: {ex.Message}";
            Console.WriteLine($"[MON-REQ {DateTime.Now:HH:mm:ss.fff}] {msg}");

            if (settings.EnableSqlLogging)
            {
                await LogMonitorToSqlAsync(runId, settings, "REQ_ERR", Trim(msg, 3500), CancellationToken.None);
            }

            await Task.Delay(settings.DmvMonitorIntervalMs, cancellationToken);
        }
    }
}

static async Task RunLockMonitorAsync(
    Guid runId,
    SimulatorSettings settings,
    ConcurrentDictionary<int, int> workerSpids,
    CancellationToken cancellationToken)
{
    while (!cancellationToken.IsCancellationRequested)
    {
        try
        {
            var spids = workerSpids.Values.Distinct().OrderBy(x => x).ToArray();
            if (spids.Length == 0)
            {
                await Task.Delay(settings.LockMonitorIntervalMs, cancellationToken);
                continue;
            }

            var inList = string.Join(", ", spids);

            await using var connection = new SqlConnection(settings.ConnectionString);
            await connection.OpenAsync(cancellationToken);

            var sql = $"""
                SELECT
                    tl.request_session_id,
                    tl.resource_type,
                    tl.request_mode,
                    tl.request_status,
                    tl.resource_description
                FROM sys.dm_tran_locks tl
                WHERE tl.request_session_id IN ({inList})
                ORDER BY tl.request_session_id, tl.resource_type, tl.request_mode;
                """;

            await using var cmd = new SqlCommand(sql, connection)
            {
                CommandTimeout = settings.CommandTimeoutSeconds
            };

            await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

            var any = false;
            while (await reader.ReadAsync(cancellationToken))
            {
                any = true;

                var msg =
                    $"LOCK session={reader.GetInt16(0)} " +
                    $"resource={reader.GetString(1)} " +
                    $"mode={reader.GetString(2)} " +
                    $"status={reader.GetString(3)} " +
                    $"desc={GetNullableString(reader, 4) ?? "-"}";

                Console.WriteLine($"[MON-LCK {DateTime.Now:HH:mm:ss.fff}] {msg}");

                if (settings.EnableSqlLogging)
                {
                    await LogMonitorToSqlAsync(runId, settings, "LOCK", msg, cancellationToken);
                }
            }

            if (!any)
            {
                var msg = "brak locków workerów";
                Console.WriteLine($"[MON-LCK {DateTime.Now:HH:mm:ss.fff}] {msg}");

                if (settings.EnableSqlLogging)
                {
                    await LogMonitorToSqlAsync(runId, settings, "LOCK", msg, cancellationToken);
                }
            }

            await Task.Delay(settings.LockMonitorIntervalMs, cancellationToken);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            var msg = $"monitor lock error: {ex.Message}";
            Console.WriteLine($"[MON-LCK {DateTime.Now:HH:mm:ss.fff}] {msg}");

            if (settings.EnableSqlLogging)
            {
                await LogMonitorToSqlAsync(runId, settings, "LOCK_ERR", Trim(msg, 3500), CancellationToken.None);
            }

            await Task.Delay(settings.LockMonitorIntervalMs, cancellationToken);
        }
    }
}

static async Task EnsureDemoTableAsync(SimulatorSettings settings)
{
    var sql = """
        IF OBJECT_ID(N'dbo.LockDemo', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.LockDemo
            (
                Id INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_LockDemo PRIMARY KEY,
                StatusName NVARCHAR(50) NOT NULL,
                Notes NVARCHAR(400) NULL
            );

            INSERT INTO dbo.LockDemo (StatusName, Notes)
            VALUES
                (N'Nowy', N'Rekord 1'),
                (N'Nowy', N'Rekord 2'),
                (N'Nowy', N'Rekord 3'),
                (N'Nowy', N'Rekord 4');
        END;
        """;

    await using var connection = new SqlConnection(settings.ConnectionString);
    await connection.OpenAsync();

    await using var cmd = new SqlCommand(sql, connection)
    {
        CommandTimeout = settings.CommandTimeoutSeconds
    };

    await cmd.ExecuteNonQueryAsync();
    Console.WriteLine("Tabela demo dbo.LockDemo jest gotowa.");
}

static async Task EnsureLogTableAsync(SimulatorSettings settings)
{
    var sql = """
        IF OBJECT_ID(N'dbo.LockSimulatorRunLog', N'U') IS NULL
        BEGIN
            CREATE TABLE dbo.LockSimulatorRunLog
            (
                LogId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_LockSimulatorRunLog PRIMARY KEY,
                RunId UNIQUEIDENTIFIER NOT NULL,
                LoggedAt DATETIME2(3) NOT NULL CONSTRAINT DF_LockSimulatorRunLog_LoggedAt DEFAULT SYSUTCDATETIME(),
                SourceType NVARCHAR(20) NOT NULL,      -- WORKER / MONITOR
                SourceName NVARCHAR(50) NOT NULL,      -- np. Worker-1 / REQ / LOCK
                WorkerId INT NULL,
                IterationNo INT NULL,
                Spid INT NULL,
                Severity NVARCHAR(10) NOT NULL,        -- INFO / WARN / ERROR
                Message NVARCHAR(4000) NOT NULL
            );

            CREATE INDEX IX_LockSimulatorRunLog_RunId_LoggedAt
                ON dbo.LockSimulatorRunLog(RunId, LoggedAt);

            CREATE INDEX IX_LockSimulatorRunLog_RunId_SourceType
                ON dbo.LockSimulatorRunLog(RunId, SourceType, LoggedAt);
        END;
        """;

    await using var connection = new SqlConnection(settings.ConnectionString);
    await connection.OpenAsync();

    await using var cmd = new SqlCommand(sql, connection)
    {
        CommandTimeout = settings.CommandTimeoutSeconds
    };

    await cmd.ExecuteNonQueryAsync();
    Console.WriteLine("Tabela logów dbo.LockSimulatorRunLog jest gotowa.");
}

static async Task LogToSqlAsync(
    Guid runId,
    SimulatorSettings settings,
    int workerId,
    int iteration,
    int? spid,
    string severity,
    string message,
    CancellationToken cancellationToken)
{
    if (!settings.EnableSqlLogging)
        return;

    var sql = """
        INSERT INTO dbo.LockSimulatorRunLog
        (
            RunId,
            SourceType,
            SourceName,
            WorkerId,
            IterationNo,
            Spid,
            Severity,
            Message
        )
        VALUES
        (
            @RunId,
            N'WORKER',
            @SourceName,
            @WorkerId,
            @IterationNo,
            @Spid,
            @Severity,
            @Message
        );
        """;

    await using var connection = new SqlConnection(settings.ConnectionString);
    await connection.OpenAsync(cancellationToken);

    await using var cmd = new SqlCommand(sql, connection)
    {
        CommandTimeout = settings.CommandTimeoutSeconds
    };

    cmd.Parameters.Add(new SqlParameter("@RunId", SqlDbType.UniqueIdentifier) { Value = runId });
    cmd.Parameters.Add(new SqlParameter("@SourceName", SqlDbType.NVarChar, 50) { Value = $"Worker-{workerId}" });
    cmd.Parameters.Add(new SqlParameter("@WorkerId", SqlDbType.Int) { Value = workerId });
    cmd.Parameters.Add(new SqlParameter("@IterationNo", SqlDbType.Int) { Value = iteration });
    cmd.Parameters.Add(new SqlParameter("@Spid", SqlDbType.Int) { Value = (object?)spid ?? DBNull.Value });
    cmd.Parameters.Add(new SqlParameter("@Severity", SqlDbType.NVarChar, 10) { Value = severity });
    cmd.Parameters.Add(new SqlParameter("@Message", SqlDbType.NVarChar, 4000) { Value = Trim(message, 4000) });

    await cmd.ExecuteNonQueryAsync(cancellationToken);
}

static async Task LogMonitorToSqlAsync(
    Guid runId,
    SimulatorSettings settings,
    string sourceName,
    string message,
    CancellationToken cancellationToken)
{
    if (!settings.EnableSqlLogging)
        return;

    var sql = """
        INSERT INTO dbo.LockSimulatorRunLog
        (
            RunId,
            SourceType,
            SourceName,
            WorkerId,
            IterationNo,
            Spid,
            Severity,
            Message
        )
        VALUES
        (
            @RunId,
            N'MONITOR',
            @SourceName,
            NULL,
            NULL,
            NULL,
            N'INFO',
            @Message
        );
        """;

    await using var connection = new SqlConnection(settings.ConnectionString);
    await connection.OpenAsync(cancellationToken);

    await using var cmd = new SqlCommand(sql, connection)
    {
        CommandTimeout = settings.CommandTimeoutSeconds
    };

    cmd.Parameters.Add(new SqlParameter("@RunId", SqlDbType.UniqueIdentifier) { Value = runId });
    cmd.Parameters.Add(new SqlParameter("@SourceName", SqlDbType.NVarChar, 50) { Value = sourceName });
    cmd.Parameters.Add(new SqlParameter("@Message", SqlDbType.NVarChar, 4000) { Value = Trim(message, 4000) });

    await cmd.ExecuteNonQueryAsync(cancellationToken);
}

static async Task<int> GetSpidAsync(SqlConnection connection, int timeoutSeconds, CancellationToken cancellationToken)
{
    await using var cmd = new SqlCommand("SELECT @@SPID;", connection)
    {
        CommandTimeout = timeoutSeconds
    };

    var result = await cmd.ExecuteScalarAsync(cancellationToken);
    return Convert.ToInt32(result);
}

static int ResolveTargetId(int workerId, int iteration, SimulatorSettings settings, Random rng)
{
    if (settings.RandomizeTargetPerIteration)
    {
        return rng.Next(settings.RandomTargetMinId, settings.RandomTargetMaxId + 1);
    }

    if (settings.WorkerTargets is { Count: > 0 })
    {
        var index = workerId - 1;
        if (index < settings.WorkerTargets.Count)
            return settings.WorkerTargets[index];
    }

    return 1;
}

static string ResolveLockHint(string mode) =>
    Normalize(mode) switch
    {
        "XLOCK" => "XLOCK, ROWLOCK",
        "UPDLOCK" => "UPDLOCK, ROWLOCK",
        "UPDLOCKREADPAST" => "UPDLOCK, READPAST, ROWLOCK",
        "UPDLOCKHOLDLOCK" => "UPDLOCK, HOLDLOCK, ROWLOCK",
        "NOHINT" => "",
        _ => throw new InvalidOperationException($"Nieznany TestMode: {mode}")
    };

static string Normalize(string value) =>
    value.Trim().Replace(" ", "", StringComparison.Ordinal).ToUpperInvariant();

static string? GetNullableString(SqlDataReader reader, int ordinal) =>
    reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);

static string Trim(string value, int maxLength) =>
    value.Length <= maxLength ? value : value[..maxLength];

static void ValidateSettings(SimulatorSettings settings)
{
    if (string.IsNullOrWhiteSpace(settings.ConnectionString))
        throw new InvalidOperationException("ConnectionString nie może być pusty.");

    if (string.IsNullOrWhiteSpace(settings.TargetTable))
        throw new InvalidOperationException("TargetTable nie może być puste.");

    if (settings.WorkerCount <= 0)
        throw new InvalidOperationException("WorkerCount musi być > 0.");

    if (settings.IterationsPerWorker <= 0)
        throw new InvalidOperationException("IterationsPerWorker musi być > 0.");

    if (settings.HoldSeconds < 0)
        throw new InvalidOperationException("HoldSeconds nie może być < 0.");

    if (settings.CommandTimeoutSeconds <= 0)
        throw new InvalidOperationException("CommandTimeoutSeconds musi być > 0.");

    if (settings.RandomTargetMinId <= 0 || settings.RandomTargetMaxId <= 0)
        throw new InvalidOperationException("RandomTargetMinId/RandomTargetMaxId muszą być > 0.");

    if (settings.RandomTargetMinId > settings.RandomTargetMaxId)
        throw new InvalidOperationException("RandomTargetMinId nie może być > RandomTargetMaxId.");
}

static void Log(int workerId, int? spid, string message)
{
    var spidText = spid.HasValue ? $"SPID={spid.Value}" : "SPID=?";
    Console.WriteLine($"[{DateTime.Now:HH:mm:ss.fff}] Worker {workerId} | {spidText} | {message}");
}

public sealed class SimulatorSettings
{
    public string ConnectionString { get; set; } = string.Empty;
    public string TargetTable { get; set; } = "dbo.LockDemo";
    public int WorkerCount { get; set; } = 4;
    public int IterationsPerWorker { get; set; } = 3;
    public List<int> WorkerTargets { get; set; } = new();
    public string TestMode { get; set; } = "XLock";
    public string Scenario { get; set; } = "Contention"; // Contention / Queue / Deadlock
    public int HoldSeconds { get; set; } = 15;
    public bool DoUpdate { get; set; }
    public int DelayBetweenSelectAndUpdateMs { get; set; }
    public int CommandTimeoutSeconds { get; set; } = 120;
    public bool CreateDemoTableIfMissing { get; set; } = true;
    public bool CreateLogTableIfMissing { get; set; } = true;
    public int StartDelayMs { get; set; } = 2000;
    public int DelayBetweenIterationsMs { get; set; } = 500;
    public bool EnableDmvMonitor { get; set; } = true;
    public int DmvMonitorIntervalMs { get; set; } = 2000;
    public bool EnableLockMonitor { get; set; } = true;
    public int LockMonitorIntervalMs { get; set; } = 2000;
    public bool EnableSqlLogging { get; set; } = true;
    public bool RandomizeTargetPerIteration { get; set; }
    public int RandomTargetMinId { get; set; } = 1;
    public int RandomTargetMaxId { get; set; } = 4;
}