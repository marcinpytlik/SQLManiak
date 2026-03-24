using System.Text.Json;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class FileStatsCollector
{
    private readonly string _connectionString;

    public FileStatsCollector(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<DmvSnapshot> CollectAsync(string runId, string phase, CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            vfs.database_id,
            DB_NAME(vfs.database_id) AS database_name,
            vfs.file_id,
            mf.type_desc,
            mf.physical_name,
            vfs.num_of_reads,
            vfs.num_of_writes,
            vfs.io_stall_read_ms,
            vfs.io_stall_write_ms,
            vfs.num_of_bytes_read,
            vfs.num_of_bytes_written
        FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
        JOIN sys.master_files mf
          ON vfs.database_id = mf.database_id
         AND vfs.file_id = mf.file_id;
        """;

        var snapshot = new DmvSnapshot
        {
            RunId = runId,
            SnapshotPhase = phase,
            SnapshotName = "FileStats",
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
                SnapshotName = "FileStats",
                CollectedAtUtc = snapshot.CollectedAtUtc,
                RowJson = JsonSerializer.Serialize(row)
            });
        }

        return snapshot;
    }
}