using Dapper;
using Microsoft.Data.SqlClient;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Repositories;

public sealed class ErrorLogRepository(ISqlConnectionFactory connectionFactory) : IErrorLogRepository
{
    public async Task<IReadOnlyList<SqlErrorLogInfo>> GetErrorLogsAsync(
        ServerProfile profile,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        CREATE TABLE #ErrorLogs
        (
            ArchiveNumber int,
            LogDate datetime,
            LogFileSizeBytes bigint
        );

        INSERT INTO #ErrorLogs
        EXEC master.dbo.sp_enumerrorlogs;

        SELECT
            ArchiveNumber,
            LogDate,
            LogFileSizeBytes
        FROM #ErrorLogs
        ORDER BY ArchiveNumber ASC;
        """;

        using var connection = connectionFactory.Create(profile);

        if (connection is SqlConnection sqlConnection)
        {
            await sqlConnection.OpenAsync(cancellationToken);
        }
        else
        {
            connection.Open();
        }

        var rows = await connection.QueryAsync<SqlErrorLogInfo>(sql);

        return rows.ToList();
    }
}