using Microsoft.Data.SqlClient;

namespace SqlStressLab.Core.Services;

public static class LifecycleScriptRunner
{
    public static async Task RunFileAsync(
        string connectionString,
        string filePath,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(filePath))
            return;

        if (!File.Exists(filePath))
            throw new FileNotFoundException($"Nie znaleziono pliku SQL: {filePath}");

        var script = await File.ReadAllTextAsync(filePath, cancellationToken);

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(script, connection)
        {
            CommandTimeout = commandTimeoutSeconds
        };

        await command.ExecuteNonQueryAsync(cancellationToken);
    }
}