using System.Data;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class BulkSampleWriter
{
    private readonly string _connectionString;

    public BulkSampleWriter(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task WriteAsync(IEnumerable<StressRunSampleRecord> samples, CancellationToken cancellationToken = default)
    {
        var table = BuildTable(samples);

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        using var bulk = new SqlBulkCopy(connection)
        {
            DestinationTableName = "dbo.StressRunSample",
            BatchSize = 5000,
            BulkCopyTimeout = 60
        };

        bulk.ColumnMappings.Add("RunId", "RunId");
        bulk.ColumnMappings.Add("WorkerId", "WorkerId");
        bulk.ColumnMappings.Add("Iteration", "Iteration");
        bulk.ColumnMappings.Add("StartedAtUtc", "StartedAtUtc");
        bulk.ColumnMappings.Add("DurationMs", "DurationMs");
        bulk.ColumnMappings.Add("Success", "Success");
        bulk.ColumnMappings.Add("RetryAttempt", "RetryAttempt");
        bulk.ColumnMappings.Add("ErrorCategory", "ErrorCategory");
        bulk.ColumnMappings.Add("SqlErrorNumber", "SqlErrorNumber");
        bulk.ColumnMappings.Add("ErrorMessage", "ErrorMessage");
        bulk.ColumnMappings.Add("ScalarValue", "ScalarValue");
        bulk.ColumnMappings.Add("ReaderRowCount", "ReaderRowCount");
        bulk.ColumnMappings.Add("Spid", "Spid");
        bulk.ColumnMappings.Add("HostName", "HostName");
        bulk.ColumnMappings.Add("AppName", "AppName");
        bulk.ColumnMappings.Add("LoginName", "LoginName");
        bulk.ColumnMappings.Add("DatabaseName", "DatabaseName");

        await bulk.WriteToServerAsync(table, cancellationToken);
    }

    private static DataTable BuildTable(IEnumerable<StressRunSampleRecord> samples)
    {
        var table = new DataTable();

        table.Columns.Add("RunId", typeof(string));
        table.Columns.Add("WorkerId", typeof(int));
        table.Columns.Add("Iteration", typeof(int));
        table.Columns.Add("StartedAtUtc", typeof(DateTime));
        table.Columns.Add("DurationMs", typeof(long));
        table.Columns.Add("Success", typeof(bool));
        table.Columns.Add("RetryAttempt", typeof(int));
        table.Columns.Add("ErrorCategory", typeof(string));
        table.Columns.Add("SqlErrorNumber", typeof(int));
        table.Columns.Add("ErrorMessage", typeof(string));
        table.Columns.Add("ScalarValue", typeof(string));
        table.Columns.Add("ReaderRowCount", typeof(int));
        table.Columns.Add("Spid", typeof(int));
        table.Columns.Add("HostName", typeof(string));
        table.Columns.Add("AppName", typeof(string));
        table.Columns.Add("LoginName", typeof(string));
        table.Columns.Add("DatabaseName", typeof(string));

        foreach (var s in samples)
        {
            table.Rows.Add(
                s.RunId,
                s.WorkerId,
                s.Iteration,
                s.StartedAtUtc,
                s.DurationMs,
                s.Success,
                s.RetryAttempt,
                (object?)s.ErrorCategory ?? DBNull.Value,
                (object?)s.SqlErrorNumber ?? DBNull.Value,
                (object?)s.ErrorMessage ?? DBNull.Value,
                (object?)s.ScalarValue ?? DBNull.Value,
                (object?)s.ReaderRowCount ?? DBNull.Value,
                (object?)s.Spid ?? DBNull.Value,
                (object?)s.HostName ?? DBNull.Value,
                (object?)s.AppName ?? DBNull.Value,
                (object?)s.LoginName ?? DBNull.Value,
                (object?)s.DatabaseName ?? DBNull.Value
            );
        }

        return table;
    }
}