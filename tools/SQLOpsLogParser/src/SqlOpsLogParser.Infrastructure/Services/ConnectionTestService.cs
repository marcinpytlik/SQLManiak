using System;
using System.Data;
using System.Diagnostics;
using Dapper;
using Microsoft.Data.SqlClient;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Services;

public sealed class ConnectionTestService(ISqlConnectionFactory connectionFactory) : IConnectionTestService
{
    public async Task<ConnectionTestResult> TestAsync(
        ServerProfile profile,
        CancellationToken cancellationToken = default)
    {
        var stopwatch = Stopwatch.StartNew();

        try
        {
            using var connection = connectionFactory.Create(profile);

            if (connection is SqlConnection sqlConnection)
            {
                await sqlConnection.OpenAsync(cancellationToken);
            }
            else
            {
                connection.Open();
            }

            var row = await connection.QuerySingleAsync<ServerInfoRow>(
                """
                SELECT
                    CAST(SERVERPROPERTY('ServerName') AS nvarchar(256)) AS ServerName,
                    CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(256)) AS ProductVersion,
                    CAST(SERVERPROPERTY('Edition') AS nvarchar(256)) AS Edition;
                """);

            stopwatch.Stop();

            return new ConnectionTestResult
            {
                Success = true,
                ServerName = row.ServerName ?? string.Empty,
                ProductVersion = row.ProductVersion,
                Edition = row.Edition,
                Duration = stopwatch.Elapsed
            };
        }
        catch (Exception ex)
        {
            stopwatch.Stop();

            return new ConnectionTestResult
            {
                Success = false,
                ErrorMessage = ex.Message,
                Duration = stopwatch.Elapsed
            };
        }
    }

    private sealed class ServerInfoRow
    {
        public string? ServerName { get; set; }
        public string? ProductVersion { get; set; }
        public string? Edition { get; set; }
    }
}