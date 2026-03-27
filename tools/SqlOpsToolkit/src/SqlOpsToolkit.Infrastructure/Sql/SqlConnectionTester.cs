using System.Diagnostics;
using Microsoft.Data.SqlClient;
using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Sql;

public sealed class SqlConnectionTester(IConnectionStringFactory connectionStringFactory) : ISqlConnectionTester
{
    public async Task<ConnectionTestResult> TestAsync(ConnectionProfile profile, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(profile);

        var stopwatch = Stopwatch.StartNew();

        try
        {
            var connectionString = connectionStringFactory.Create(profile);

            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            await using var command = new SqlCommand("SELECT 1;", connection);
            await command.ExecuteScalarAsync(cancellationToken);

            stopwatch.Stop();

            return new ConnectionTestResult
            {
                ProfileName = profile.Name,
                Server = profile.Server,
                ConnectOk = true,
                Message = "Połączenie zakończone sukcesem.",
                CheckedAtUtc = DateTime.UtcNow,
                DurationMs = stopwatch.ElapsedMilliseconds
            };
        }
        catch (Exception ex)
        {
            stopwatch.Stop();

            return new ConnectionTestResult
            {
                ProfileName = profile.Name,
                Server = profile.Server,
                ConnectOk = false,
                Message = ex.Message,
                CheckedAtUtc = DateTime.UtcNow,
                DurationMs = stopwatch.ElapsedMilliseconds
            };
        }
    }
}