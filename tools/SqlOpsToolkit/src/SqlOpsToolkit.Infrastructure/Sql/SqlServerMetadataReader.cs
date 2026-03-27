using Microsoft.Data.SqlClient;
using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Sql;

public sealed class SqlServerMetadataReader(IConnectionStringFactory connectionStringFactory) : ISqlServerMetadataReader
{
    private const string MetadataQuery = """
        SELECT
            CAST(@@SERVERNAME AS nvarchar(256)) AS ServerName,
            CAST(SERVERPROPERTY('MachineName') AS nvarchar(256)) AS MachineName,
            CAST(SERVERPROPERTY('InstanceName') AS nvarchar(256)) AS InstanceName,
            CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) AS Edition,
            CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(256)) AS ProductVersion,
            CAST(SERVERPROPERTY('ProductLevel') AS nvarchar(256)) AS ProductLevel,
            CAST(SERVERPROPERTY('ProductUpdateLevel') AS nvarchar(256)) AS ProductUpdateLevel,
            CAST(SERVERPROPERTY('ProductUpdateReference') AS nvarchar(256)) AS ProductUpdateReference,
            CAST(SERVERPROPERTY('EngineEdition') AS int) AS EngineEdition;
        """;

    public async Task<SqlServerInstanceMetadata> ReadAsync(ConnectionProfile profile, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(profile);

        var connectionString = connectionStringFactory.Create(profile);

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        await using var command = new SqlCommand(MetadataQuery, connection);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            throw new InvalidOperationException("Zapytanie metadanych nie zwróciło żadnego wiersza.");

        var productVersion = GetString(reader, "ProductVersion");
        var parts = SqlVersionParser.Parse(productVersion);

        return new SqlServerInstanceMetadata
        {
            ProfileName = profile.Name,
            ServerName = GetString(reader, "ServerName"),
            MachineName = GetString(reader, "MachineName"),
            InstanceName = GetNullableString(reader, "InstanceName"),
            Edition = GetString(reader, "Edition"),
            ProductVersion = productVersion,
            ProductLevel = GetString(reader, "ProductLevel"),
            ProductUpdateLevel = GetString(reader, "ProductUpdateLevel"),
            ProductUpdateReference = GetString(reader, "ProductUpdateReference"),
            EngineEdition = GetNullableInt(reader, "EngineEdition"),
            MajorVersion = parts.Major,
            VersionMajor = parts.Major,
            VersionMinor = parts.Minor,
            VersionBuild = parts.Build,
            VersionRevision = parts.Revision,
            CollectedAtUtc = DateTime.UtcNow
        };
    }

    private static string GetString(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? string.Empty : reader.GetString(ordinal);
    }

    private static string? GetNullableString(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetString(ordinal);
    }

    private static int? GetNullableInt(SqlDataReader reader, string columnName)
    {
        var ordinal = reader.GetOrdinal(columnName);
        return reader.IsDBNull(ordinal) ? null : reader.GetInt32(ordinal);
    }
}