using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class SqlServerEnvironmentCollector
{
    private readonly string _connectionString;

    public SqlServerEnvironmentCollector(string connectionString)
    {
        _connectionString = connectionString;
    }

    public async Task<SqlServerEnvironmentInfo> CollectAsync(CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(128)) AS ProductVersion,
            CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(128)) AS ProductLevel,
            CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) AS Edition,
            CAST(SERVERPROPERTY('EngineEdition') AS nvarchar(128)) AS EngineEdition,
            CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS ServerName,
            CAST(SERVERPROPERTY('MachineName') AS nvarchar(256)) AS MachineName,
            CAST(ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS nvarchar(256)) AS InstanceName,
            DB_NAME() AS DatabaseName,
            compatibility_level
        FROM sys.databases
        WHERE name = DB_NAME();
        """;

        await using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, connection);
        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        if (await reader.ReadAsync(cancellationToken))
        {
            return new SqlServerEnvironmentInfo
            {
                ProductVersion = reader["ProductVersion"]?.ToString() ?? "",
                ProductLevel = reader["ProductLevel"]?.ToString() ?? "",
                Edition = reader["Edition"]?.ToString() ?? "",
                EngineEdition = reader["EngineEdition"]?.ToString() ?? "",
                ServerName = reader["ServerName"]?.ToString() ?? "",
                MachineName = reader["MachineName"]?.ToString() ?? "",
                InstanceName = reader["InstanceName"]?.ToString() ?? "",
                DatabaseName = reader["DatabaseName"]?.ToString() ?? "",
                CompatibilityLevel = Convert.ToInt32(reader["compatibility_level"])
            };
        }

        return new SqlServerEnvironmentInfo();
    }
}