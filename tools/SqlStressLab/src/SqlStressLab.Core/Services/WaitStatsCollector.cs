using System.Text.Json;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class WaitStatsCollector
{
    private readonly string _connectionString;

    public WaitStatsCollector(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<DmvSnapshot> CollectAsync(string runId, string phase, CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            wait_type,
            waiting_tasks_count,
            wait_time_ms,
            signal_wait_time_ms
        FROM sys.dm_os_wait_stats
        WHERE wait_type NOT LIKE 'SLEEP%'
          AND wait_type NOT LIKE 'BROKER_%'
          AND wait_type NOT LIKE 'XE_%';
        """;

        var snapshot = new DmvSnapshot
        {
            RunId = runId,
            SnapshotPhase = phase,
            SnapshotName = "WaitStats",
            CollectedAtUtc = DateTime.UtcNow
        };

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, conn);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            var row = new Dictionary<string, object?>
            {
                ["wait_type"] = reader["wait_type"],
                ["waiting_tasks_count"] = reader["waiting_tasks_count"],
                ["wait_time_ms"] = reader["wait_time_ms"],
                ["signal_wait_time_ms"] = reader["signal_wait_time_ms"]
            };

            snapshot.Rows.Add(new DmvSnapshotRow
            {
                RunId = runId,
                SnapshotPhase = phase,
                SnapshotName = "WaitStats",
                CollectedAtUtc = snapshot.CollectedAtUtc,
                RowJson = JsonSerializer.Serialize(row)
            });
        }

        return snapshot;
    }
}