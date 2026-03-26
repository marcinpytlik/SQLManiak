using Dapper;
using Microsoft.Data.SqlClient;
using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Repositories;

public sealed class JobRepository(ISqlConnectionFactory connectionFactory) : IJobRepository
{
    public async Task<IReadOnlyList<JobInfo>> GetJobsAsync(
        ServerProfile profile,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            j.job_id AS JobId,
            j.name AS Name,
            j.enabled AS Enabled,
            SUSER_SNAME(j.owner_sid) AS OwnerLoginName,
            ISNULL(j.description, N'') AS Description
        FROM msdb.dbo.sysjobs AS j
        ORDER BY j.name;
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

        var rows = await connection.QueryAsync<JobInfo>(sql);

        return rows.ToList();
    }

    public async Task<IReadOnlyList<JobExecution>> GetFailedJobsAsync(
        ServerProfile profile,
        int hours,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        WITH JobHistory AS
        (
            SELECT
                j.job_id AS JobId,
                j.name AS JobName,
                msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
                ((h.run_duration / 10000) * 3600)
                    + (((h.run_duration % 10000) / 100) * 60)
                    + (h.run_duration % 100) AS RunDurationSeconds,
                h.run_status AS RunStatus,
                h.sql_message_id AS SqlMessageId,
                h.sql_severity AS SqlSeverity,
                ISNULL(h.message, N'') AS Message
            FROM msdb.dbo.sysjobhistory AS h
            INNER JOIN msdb.dbo.sysjobs AS j
                ON j.job_id = h.job_id
            WHERE h.step_id = 0
              AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= DATEADD(HOUR, -@Hours, GETDATE())
              AND h.run_status = 0
        )
        SELECT
            JobId,
            JobName,
            RunDateTime,
            RunDurationSeconds,
            RunStatus,
            SqlMessageId,
            SqlSeverity,
            Message
        FROM JobHistory
        ORDER BY RunDateTime DESC;
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

        var rows = await connection.QueryAsync<JobExecutionRow>(sql, new { Hours = hours });

        return rows.Select(MapExecution).ToList();
    }

    public async Task<IReadOnlyList<JobExecution>> GetJobHistoryAsync(
        ServerProfile profile,
        string jobName,
        int? top = null,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT TOP (@Top)
            j.job_id AS JobId,
            j.name AS JobName,
            msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
            ((h.run_duration / 10000) * 3600)
                + (((h.run_duration % 10000) / 100) * 60)
                + (h.run_duration % 100) AS RunDurationSeconds,
            h.run_status AS RunStatus,
            h.sql_message_id AS SqlMessageId,
            h.sql_severity AS SqlSeverity,
            ISNULL(h.message, N'') AS Message
        FROM msdb.dbo.sysjobhistory AS h
        INNER JOIN msdb.dbo.sysjobs AS j
            ON j.job_id = h.job_id
        WHERE h.step_id = 0
          AND j.name = @JobName
        ORDER BY msdb.dbo.agent_datetime(h.run_date, h.run_time) DESC;
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

        var rows = await connection.QueryAsync<JobExecutionRow>(
            sql,
            new
            {
                JobName = jobName,
                Top = top ?? 20
            });

        return rows.Select(MapExecution).ToList();
    }

    private static JobExecution MapExecution(JobExecutionRow row)
    {
        return new JobExecution
        {
            JobId = row.JobId,
            JobName = row.JobName ?? string.Empty,
            RunDateTime = row.RunDateTime,
            RunDurationSeconds = row.RunDurationSeconds,
            Status = MapStatus(row.RunStatus),
            SqlMessageId = row.SqlMessageId,
            SqlSeverity = row.SqlSeverity,
            Message = row.Message ?? string.Empty
        };
    }

    private static JobExecutionStatus MapStatus(int runStatus)
    {
        return runStatus switch
        {
            0 => JobExecutionStatus.Failed,
            1 => JobExecutionStatus.Succeeded,
            2 => JobExecutionStatus.Retry,
            3 => JobExecutionStatus.Cancelled,
            4 => JobExecutionStatus.InProgress,
            _ => JobExecutionStatus.Unknown
        };
    }

    private sealed class JobExecutionRow
    {
        public Guid JobId { get; set; }
        public string? JobName { get; set; }
        public DateTime? RunDateTime { get; set; }
        public int RunDurationSeconds { get; set; }
        public int RunStatus { get; set; }
        public int SqlMessageId { get; set; }
        public int SqlSeverity { get; set; }
        public string? Message { get; set; }
    }
}