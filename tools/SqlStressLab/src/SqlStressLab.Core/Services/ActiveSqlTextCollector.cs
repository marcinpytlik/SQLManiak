using System.Text.Json;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class ActiveSqlTextCollector
{
    private readonly string _connectionString;

    public ActiveSqlTextCollector(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<DmvSnapshot> CollectAsync(string runId, string phase, CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            r.session_id,
            r.request_id,
            r.status,
            r.command,
            r.cpu_time,
            r.total_elapsed_time,
            r.logical_reads,
            r.writes,
            DB_NAME(r.database_id) AS database_name,
            st.text AS sql_text
        FROM sys.dm_exec_requests r
        OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) st;
        """;

        var snapshot = new DmvSnapshot
        {
            RunId = runId,
            SnapshotPhase = phase,
            SnapshotName = "ActiveSqlText",
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
                SnapshotName = "ActiveSqlText",
                CollectedAtUtc = snapshot.CollectedAtUtc,
                RowJson = JsonSerializer.Serialize(row)
            });
        }

        return snapshot;
    }
}