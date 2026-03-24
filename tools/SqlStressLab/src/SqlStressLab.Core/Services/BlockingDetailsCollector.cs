using System.Text.Json;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class BlockingDetailsCollector
{
    private readonly string _connectionString;

    public BlockingDetailsCollector(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<DmvSnapshot> CollectAsync(string runId, string phase, CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            r.session_id,
            r.blocking_session_id,
            r.status,
            r.command,
            r.wait_type,
            r.wait_time,
            r.cpu_time,
            r.total_elapsed_time,
            DB_NAME(r.database_id) AS database_name,
            s.host_name,
            s.program_name,
            s.login_name,
            st.text AS sql_text
        FROM sys.dm_exec_requests r
        JOIN sys.dm_exec_sessions s
          ON r.session_id = s.session_id
        OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st
        WHERE r.blocking_session_id <> 0
           OR EXISTS
              (
                  SELECT 1
                  FROM sys.dm_os_waiting_tasks wt
                  WHERE wt.session_id = r.session_id
                    AND wt.blocking_session_id IS NOT NULL
                    AND wt.blocking_session_id > 0
              );
        """;

        var snapshot = new DmvSnapshot
        {
            RunId = runId,
            SnapshotPhase = phase,
            SnapshotName = "BlockingDetails",
            CollectedAtUtc = DateTime.UtcNow
        };

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, conn);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            var row = new Dictionary<string, object?>();

            for (int i = 0; i < reader.FieldCount; i++)
            {
                row[reader.GetName(i)] = await reader.IsDBNullAsync(i, cancellationToken)
                    ? null
                    : reader.GetValue(i);
            }

            snapshot.Rows.Add(new DmvSnapshotRow
            {
                RunId = runId,
                SnapshotPhase = phase,
                SnapshotName = "BlockingDetails",
                CollectedAtUtc = snapshot.CollectedAtUtc,
                RowJson = JsonSerializer.Serialize(row)
            });
        }

        return snapshot;
    }
}