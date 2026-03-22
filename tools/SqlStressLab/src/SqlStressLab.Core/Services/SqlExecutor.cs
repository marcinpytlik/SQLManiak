using System.Data;
using System.Text.Json;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Enums;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class SqlExecutor
{
    public static async Task ExecuteAsync(
        SqlConnection connection,
        SqlTransaction? transaction,
        StressOptions options,
        ExecutionSample sample,
        int workerId,
        int iteration,
        CancellationToken cancellationToken)
    {
        await using var cmd = new SqlCommand(options.CommandText, connection, transaction)
        {
            CommandTimeout = options.CommandTimeoutSeconds,
            CommandType = string.Equals(options.CommandType, "StoredProcedure", StringComparison.OrdinalIgnoreCase)
                ? CommandType.StoredProcedure
                : CommandType.Text
        };

        foreach (var p in options.Parameters)
        {
            cmd.Parameters.Add(ParameterValueFactory.Create(p, workerId, iteration));
        }

        var mode = Enum.TryParse<ExecutionMode>(options.ExecutionMode, true, out var parsed)
            ? parsed
            : ExecutionMode.NonQuery;

        switch (mode)
        {
            case ExecutionMode.NonQuery:
                await cmd.ExecuteNonQueryAsync(cancellationToken);
                break;

            case ExecutionMode.Scalar:
                var scalar = await cmd.ExecuteScalarAsync(cancellationToken);
                sample.ScalarValue = scalar?.ToString();
                break;

            case ExecutionMode.Reader:
                await using (var reader = await cmd.ExecuteReaderAsync(cancellationToken))
                {
                    var previewRows = new List<Dictionary<string, object?>>();
                    int count = 0;

                    while (await reader.ReadAsync(cancellationToken))
                    {
                        count++;

                        if (count <= 10)
                        {
                            var row = new Dictionary<string, object?>();
                            for (int i = 0; i < reader.FieldCount; i++)
                            {
                                row[reader.GetName(i)] = await reader.IsDBNullAsync(i, cancellationToken)
                                    ? null
                                    : reader.GetValue(i);
                            }
                            previewRows.Add(row);
                        }
                    }

                    sample.ReaderRowCount = count;
                    sample.ReaderPreviewJson = JsonSerializer.Serialize(previewRows);
                }
                break;
        }
    }
}