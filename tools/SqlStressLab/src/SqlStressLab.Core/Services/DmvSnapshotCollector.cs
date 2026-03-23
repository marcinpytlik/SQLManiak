using System.Text.Json;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class DmvSnapshotCollector
{
    private readonly string _connectionString;

    public DmvSnapshotCollector(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<List<DmvSnapshot>> CollectAllAsync(
        string runId,
        string phase,
        CancellationToken cancellationToken = default)
    {
        var snapshots = new List<DmvSnapshot>
        {
            await CollectAsync(runId, phase, "Requests", SqlScripts.Requests, cancellationToken),
            await CollectAsync(runId, phase, "WaitingTasks", SqlScripts.WaitingTasks, cancellationToken),
            await CollectAsync(runId, phase, "Locks", SqlScripts.Locks, cancellationToken),
            await CollectAsync(runId, phase, "Sessions", SqlScripts.Sessions, cancellationToken)
        };

        return snapshots;
    }

    private async Task<DmvSnapshot> CollectAsync(
        string runId,
        string phase,
        string snapshotName,
        string sql,
        CancellationToken cancellationToken)
    {
        var snapshot = new DmvSnapshot
        {
            RunId = runId,
            SnapshotPhase = phase,
            SnapshotName = snapshotName,
            CollectedAtUtc = DateTime.UtcNow
        };

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(sql, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            var dict = new Dictionary<string, object?>();

            for (int i = 0; i < reader.FieldCount; i++)
            {
                dict[reader.GetName(i)] = await reader.IsDBNullAsync(i, cancellationToken)
                    ? null
                    : reader.GetValue(i);
            }

            snapshot.Rows.Add(new DmvSnapshotRow
            {
                RunId = runId,
                SnapshotPhase = phase,
                SnapshotName = snapshotName,
                CollectedAtUtc = snapshot.CollectedAtUtc,
                RowJson = JsonSerializer.Serialize(dict)
            });
        }

        return snapshot;
    }

    private static class SqlScripts
    {
        public const string Requests = """
        SELECT
            session_id,
            status,
            command,
            blocking_session_id,
            wait_type,
            wait_time,
            cpu_time,
            total_elapsed_time,
            logical_reads,
            writes,
            database_id
        FROM sys.dm_exec_requests;
        """;

        public const string WaitingTasks = """
        SELECT
            session_id,
            exec_context_id,
            wait_duration_ms,
            wait_type,
            blocking_session_id,
            resource_description
        FROM sys.dm_os_waiting_tasks;
        """;

        public const string Locks = """
        SELECT
            request_session_id,
            resource_type,
            resource_database_id,
            request_mode,
            request_status
        FROM sys.dm_tran_locks;
        """;

        public const string Sessions = """
        SELECT
            session_id,
            login_name,
            host_name,
            program_name,
            status,
            cpu_time,
            memory_usage,
            total_scheduled_time
        FROM sys.dm_exec_sessions
        WHERE is_user_process = 1;
        """;
    }
}