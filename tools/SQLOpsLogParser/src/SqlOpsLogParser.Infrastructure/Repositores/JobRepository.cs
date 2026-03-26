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
        string? jobName = null,
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
              AND (@JobName IS NULL OR j.name = @JobName)
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

        var rows = await connection.QueryAsync<JobExecutionRow>(
            sql,
            new
            {
                Hours = hours,
                JobName = jobName
            });

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

    public async Task<IReadOnlyList<JobStepInfo>> GetJobStepsAsync(
        ServerProfile profile,
        string jobName,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            j.job_id AS JobId,
            j.name AS JobName,
            s.step_id AS StepId,
            s.step_name AS StepName,
            ISNULL(s.subsystem, N'') AS Subsystem,
            ISNULL(s.database_name, N'') AS DatabaseName,
            ISNULL(s.command, N'') AS Command,
            s.on_success_action AS OnSuccessAction,
            s.on_fail_action AS OnFailAction
        FROM msdb.dbo.sysjobsteps AS s
        INNER JOIN msdb.dbo.sysjobs AS j
            ON j.job_id = s.job_id
        WHERE j.name = @JobName
        ORDER BY s.step_id;
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

        var rows = await connection.QueryAsync<JobStepInfo>(sql, new { JobName = jobName });
        return rows.ToList();
    }

    public async Task<IReadOnlyList<JobStepExecution>> GetJobStepHistoryAsync(
        ServerProfile profile,
        string jobName,
        int? top = null,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT TOP (@Top)
            j.job_id AS JobId,
            j.name AS JobName,
            h.step_id AS StepId,
            ISNULL(h.step_name, N'') AS StepName,
            msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
            ((h.run_duration / 10000) * 3600)
                + (((h.run_duration % 10000) / 100) * 60)
                + (h.run_duration % 100) AS RunDurationSeconds,
            h.run_status AS RunStatus,
            h.sql_message_id AS SqlMessageId,
            h.sql_severity AS SqlSeverity,
            ISNULL(h.message, N'') AS Message,
            ISNULL(s.database_name, N'') AS DatabaseName,
            ISNULL(s.subsystem, N'') AS Subsystem
        FROM msdb.dbo.sysjobhistory AS h
        INNER JOIN msdb.dbo.sysjobs AS j
            ON j.job_id = h.job_id
        LEFT JOIN msdb.dbo.sysjobsteps AS s
            ON s.job_id = h.job_id
           AND s.step_id = h.step_id
        WHERE h.step_id > 0
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

        var rows = await connection.QueryAsync<JobStepExecutionRow>(
            sql,
            new
            {
                JobName = jobName,
                Top = top ?? 50
            });

        return rows.Select(MapStepExecution).ToList();
    }

    public async Task<IReadOnlyList<JobStepExecution>> GetFailedJobStepsAsync(
        ServerProfile profile,
        int hours,
        string? jobName = null,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT
            j.job_id AS JobId,
            j.name AS JobName,
            h.step_id AS StepId,
            ISNULL(h.step_name, N'') AS StepName,
            msdb.dbo.agent_datetime(h.run_date, h.run_time) AS RunDateTime,
            ((h.run_duration / 10000) * 3600)
                + (((h.run_duration % 10000) / 100) * 60)
                + (h.run_duration % 100) AS RunDurationSeconds,
            h.run_status AS RunStatus,
            h.sql_message_id AS SqlMessageId,
            h.sql_severity AS SqlSeverity,
            ISNULL(h.message, N'') AS Message,
            ISNULL(s.database_name, N'') AS DatabaseName,
            ISNULL(s.subsystem, N'') AS Subsystem
        FROM msdb.dbo.sysjobhistory AS h
        INNER JOIN msdb.dbo.sysjobs AS j
            ON j.job_id = h.job_id
        LEFT JOIN msdb.dbo.sysjobsteps AS s
            ON s.job_id = h.job_id
           AND s.step_id = h.step_id
        WHERE h.step_id > 0
          AND h.run_status = 0
          AND msdb.dbo.agent_datetime(h.run_date, h.run_time) >= DATEADD(HOUR, -@Hours, GETDATE())
          AND (@JobName IS NULL OR j.name = @JobName)
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

        var rows = await connection.QueryAsync<JobStepExecutionRow>(
            sql,
            new
            {
                Hours = hours,
                JobName = jobName
            });

        return rows.Select(MapStepExecution).ToList();
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

    private static JobStepExecution MapStepExecution(JobStepExecutionRow row)
    {
        return new JobStepExecution
        {
            JobId = row.JobId,
            JobName = row.JobName ?? string.Empty,
            StepId = row.StepId,
            StepName = row.StepName ?? string.Empty,
            RunDateTime = row.RunDateTime,
            RunDurationSeconds = row.RunDurationSeconds,
            Status = MapStatus(row.RunStatus),
            SqlMessageId = row.SqlMessageId,
            SqlSeverity = row.SqlSeverity,
            Message = row.Message ?? string.Empty,
            DatabaseName = row.DatabaseName,
            Subsystem = row.Subsystem
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

    private sealed class JobStepExecutionRow
    {
        public Guid JobId { get; set; }
        public string? JobName { get; set; }
        public int StepId { get; set; }
        public string? StepName { get; set; }
        public DateTime? RunDateTime { get; set; }
        public int RunDurationSeconds { get; set; }
        public int RunStatus { get; set; }
        public int SqlMessageId { get; set; }
        public int SqlSeverity { get; set; }
        public string? Message { get; set; }
        public string? DatabaseName { get; set; }
        public string? Subsystem { get; set; }
    }
}