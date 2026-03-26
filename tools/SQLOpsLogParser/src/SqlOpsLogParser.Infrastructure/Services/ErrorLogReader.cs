using Dapper;
using Microsoft.Data.SqlClient;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Services;

public sealed class ErrorLogReader(ISqlConnectionFactory connectionFactory) : IErrorLogReader
{
    public async Task<IReadOnlyList<SqlLogEntry>> ReadAsync(
        ErrorLogReadRequest request,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        CREATE TABLE #ErrorLog
        (
            LogDate datetime NULL,
            ProcessInfo nvarchar(64) NULL,
            [Text] nvarchar(max) NULL
        );

        INSERT INTO #ErrorLog
        EXEC master.dbo.xp_readerrorlog
            @ArchiveNumber,
            1,
            @SearchText1,
            NULL,
            @FromDate,
            @ToDate,
            N'asc';

        SELECT
            LogDate,
            ISNULL(ProcessInfo, N'') AS ProcessInfo,
            ISNULL([Text], N'') AS [Text]
        FROM #ErrorLog
        ORDER BY LogDate ASC;
        """;

        using var connection = connectionFactory.Create(request.Profile);

        if (connection is SqlConnection sqlConnection)
        {
            await sqlConnection.OpenAsync(cancellationToken);
        }
        else
        {
            connection.Open();
        }

        var rows = await connection.QueryAsync<SqlLogEntry>(
            sql,
            new
            {
                ArchiveNumber = request.LogNumber,
                SearchText1 = request.ContainsText,
                FromDate = request.From,
                ToDate = request.To
            });

        var result = rows.ToList();

        if (request.Top is > 0)
        {
            result = result.Take(request.Top.Value).ToList();
        }

        return result;
    }
}