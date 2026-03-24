using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class SqlResultRepository
{
    private readonly string _connectionString;

    public SqlResultRepository(string connectionString)
    {
        _connectionString = connectionString;
    }
public async Task InsertComparisonAsync(
    StressRunComparisonRecord record,
    CancellationToken cancellationToken = default)
{
    const string sql = """
    INSERT INTO dbo.StressRunComparison
    (
        RunId,
        BaselineRunId,
        AvgDurationDeltaMs,
        P95DurationDeltaMs,
        ThroughputDelta,
        ErrorCountDelta,
        RetryCountDelta,
        IsRegression,
        ComparedAtUtc
    )
    VALUES
    (
        @RunId,
        @BaselineRunId,
        @AvgDurationDeltaMs,
        @P95DurationDeltaMs,
        @ThroughputDelta,
        @ErrorCountDelta,
        @RetryCountDelta,
        @IsRegression,
        @ComparedAtUtc
    );
    """;

    await using var conn = new SqlConnection(_connectionString);
    await conn.OpenAsync(cancellationToken);

    await using var cmd = new SqlCommand(sql, conn);

    cmd.Parameters.AddWithValue("@RunId", record.RunId);
    cmd.Parameters.AddWithValue("@BaselineRunId", record.BaselineRunId);
    cmd.Parameters.AddWithValue("@AvgDurationDeltaMs", record.AvgDurationDeltaMs);
    cmd.Parameters.AddWithValue("@P95DurationDeltaMs", record.P95DurationDeltaMs);
    cmd.Parameters.AddWithValue("@ThroughputDelta", record.ThroughputDelta);
    cmd.Parameters.AddWithValue("@ErrorCountDelta", record.ErrorCountDelta);
    cmd.Parameters.AddWithValue("@RetryCountDelta", record.RetryCountDelta);
    cmd.Parameters.AddWithValue("@IsRegression", record.IsRegression);
    cmd.Parameters.AddWithValue("@ComparedAtUtc", record.ComparedAtUtc);

    await cmd.ExecuteNonQueryAsync(cancellationToken);
}

    public async Task InsertRunAsync(StressRunRecord run, CancellationToken cancellationToken = default)
    {
        const string sql = """
        INSERT INTO dbo.StressRun
        (
            RunId,
            ProfileName,
            ScenarioName,
            TagsCsv,
            EnvironmentName,
            MachineName,
            OsVersion,
            DotNetVersion,
            ServerName,
            DatabaseName,
            CommandType,
            ExecutionMode,
            Workers,
            IterationsPerWorker,
            TotalExecutions,
            SuccessCount,
            ErrorCount,
            RetryCount,
            AvgDurationMs,
            MinDurationMs,
            P50DurationMs,
            P95DurationMs,
            P99DurationMs,
            MaxDurationMs,
            ThroughputPerSecond,
            StartedAtUtc,
            FinishedAtUtc,
            WallClockMs,
            SqlProductVersion,
            SqlProductLevel,
            SqlEdition,
            SqlEngineEdition,
            SqlInstanceName,
            SqlCompatibilityLevel
        )
        VALUES
        (
            @RunId,
            @ProfileName,
            @ScenarioName,
            @TagsCsv,
            @EnvironmentName,
            @MachineName,
            @OsVersion,
            @DotNetVersion,
            @ServerName,
            @DatabaseName,
            @CommandType,
            @ExecutionMode,
            @Workers,
            @IterationsPerWorker,
            @TotalExecutions,
            @SuccessCount,
            @ErrorCount,
            @RetryCount,
            @AvgDurationMs,
            @MinDurationMs,
            @P50DurationMs,
            @P95DurationMs,
            @P99DurationMs,
            @MaxDurationMs,
            @ThroughputPerSecond,
            @StartedAtUtc,
            @FinishedAtUtc,
            @WallClockMs,
            @SqlProductVersion,
            @SqlProductLevel,
            @SqlEdition,
            @SqlEngineEdition,
            @SqlInstanceName,
            @SqlCompatibilityLevel
        );
        """;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, conn);

        cmd.Parameters.AddWithValue("@RunId", run.RunId);
        cmd.Parameters.AddWithValue("@ProfileName", run.ProfileName);
        cmd.Parameters.AddWithValue("@ScenarioName", run.ScenarioName);
        cmd.Parameters.AddWithValue("@TagsCsv", (object?)run.TagsCsv ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@EnvironmentName", (object?)run.EnvironmentName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@MachineName", (object?)run.MachineName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@OsVersion", (object?)run.OsVersion ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@DotNetVersion", (object?)run.DotNetVersion ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@ServerName", run.ServerName);
        cmd.Parameters.AddWithValue("@DatabaseName", run.DatabaseName);
        cmd.Parameters.AddWithValue("@CommandType", run.CommandType);
        cmd.Parameters.AddWithValue("@ExecutionMode", run.ExecutionMode);
        cmd.Parameters.AddWithValue("@Workers", run.Workers);
        cmd.Parameters.AddWithValue("@IterationsPerWorker", run.IterationsPerWorker);
        cmd.Parameters.AddWithValue("@TotalExecutions", run.TotalExecutions);
        cmd.Parameters.AddWithValue("@SuccessCount", run.SuccessCount);
        cmd.Parameters.AddWithValue("@ErrorCount", run.ErrorCount);
        cmd.Parameters.AddWithValue("@RetryCount", run.RetryCount);
        cmd.Parameters.AddWithValue("@AvgDurationMs", run.AvgDurationMs);
        cmd.Parameters.AddWithValue("@MinDurationMs", run.MinDurationMs);
        cmd.Parameters.AddWithValue("@P50DurationMs", run.P50DurationMs);
        cmd.Parameters.AddWithValue("@P95DurationMs", run.P95DurationMs);
        cmd.Parameters.AddWithValue("@P99DurationMs", run.P99DurationMs);
        cmd.Parameters.AddWithValue("@MaxDurationMs", run.MaxDurationMs);
        cmd.Parameters.AddWithValue("@ThroughputPerSecond", run.ThroughputPerSecond);
        cmd.Parameters.AddWithValue("@StartedAtUtc", run.StartedAtUtc);
        cmd.Parameters.AddWithValue("@FinishedAtUtc", run.FinishedAtUtc);
        cmd.Parameters.AddWithValue("@WallClockMs", run.WallClockMs);

        cmd.Parameters.AddWithValue("@SqlProductVersion", (object?)run.SqlProductVersion ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SqlProductLevel", (object?)run.SqlProductLevel ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SqlEdition", (object?)run.SqlEdition ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SqlEngineEdition", (object?)run.SqlEngineEdition ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SqlInstanceName", (object?)run.SqlInstanceName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@SqlCompatibilityLevel", run.SqlCompatibilityLevel == 0 ? DBNull.Value : run.SqlCompatibilityLevel);

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task InsertSamplesAsync(IEnumerable<StressRunSampleRecord> samples, CancellationToken cancellationToken = default)
    {
        const string sql = """
        INSERT INTO dbo.StressRunSample
        (
            RunId,
            WorkerId,
            Iteration,
            StartedAtUtc,
            DurationMs,
            Success,
            RetryAttempt,
            ErrorCategory,
            SqlErrorNumber,
            ErrorMessage,
            ScalarValue,
            ReaderRowCount,
            Spid,
            HostName,
            AppName,
            LoginName,
            DatabaseName
        )
        VALUES
        (
            @RunId,
            @WorkerId,
            @Iteration,
            @StartedAtUtc,
            @DurationMs,
            @Success,
            @RetryAttempt,
            @ErrorCategory,
            @SqlErrorNumber,
            @ErrorMessage,
            @ScalarValue,
            @ReaderRowCount,
            @Spid,
            @HostName,
            @AppName,
            @LoginName,
            @DatabaseName
        );
        """;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        foreach (var sample in samples)
        {
            await using var cmd = new SqlCommand(sql, conn);

            cmd.Parameters.AddWithValue("@RunId", sample.RunId);
            cmd.Parameters.AddWithValue("@WorkerId", sample.WorkerId);
            cmd.Parameters.AddWithValue("@Iteration", sample.Iteration);
            cmd.Parameters.AddWithValue("@StartedAtUtc", sample.StartedAtUtc);
            cmd.Parameters.AddWithValue("@DurationMs", sample.DurationMs);
            cmd.Parameters.AddWithValue("@Success", sample.Success);
            cmd.Parameters.AddWithValue("@RetryAttempt", sample.RetryAttempt);
            cmd.Parameters.AddWithValue("@ErrorCategory", (object?)sample.ErrorCategory ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@SqlErrorNumber", (object?)sample.SqlErrorNumber ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@ErrorMessage", (object?)sample.ErrorMessage ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@ScalarValue", (object?)sample.ScalarValue ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@ReaderRowCount", (object?)sample.ReaderRowCount ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@Spid", (object?)sample.Spid ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@HostName", (object?)sample.HostName ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@AppName", (object?)sample.AppName ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@LoginName", (object?)sample.LoginName ?? DBNull.Value);
            cmd.Parameters.AddWithValue("@DatabaseName", (object?)sample.DatabaseName ?? DBNull.Value);

            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
    }

    public async Task InsertDmvSnapshotsAsync(IEnumerable<DmvSnapshotRow> rows, CancellationToken cancellationToken = default)
    {
        const string sql = """
        INSERT INTO dbo.StressRunDmvSnapshot
        (
            RunId,
            SnapshotPhase,
            SnapshotName,
            CollectedAtUtc,
            RowJson
        )
        VALUES
        (
            @RunId,
            @SnapshotPhase,
            @SnapshotName,
            @CollectedAtUtc,
            @RowJson
        );
        """;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        foreach (var row in rows)
        {
            await using var cmd = new SqlCommand(sql, conn);

            cmd.Parameters.AddWithValue("@RunId", row.RunId);
            cmd.Parameters.AddWithValue("@SnapshotPhase", row.SnapshotPhase);
            cmd.Parameters.AddWithValue("@SnapshotName", row.SnapshotName);
            cmd.Parameters.AddWithValue("@CollectedAtUtc", row.CollectedAtUtc);
            cmd.Parameters.AddWithValue("@RowJson", row.RowJson);

            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
    }

    public async Task<StressRunRecord?> GetRunByIdAsync(string runId, CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT TOP (1)
            RunId,
            ProfileName,
            ScenarioName,
            TagsCsv,
            EnvironmentName,
            MachineName,
            OsVersion,
            DotNetVersion,
            ServerName,
            DatabaseName,
            CommandType,
            ExecutionMode,
            Workers,
            IterationsPerWorker,
            TotalExecutions,
            SuccessCount,
            ErrorCount,
            RetryCount,
            AvgDurationMs,
            MinDurationMs,
            P50DurationMs,
            P95DurationMs,
            P99DurationMs,
            MaxDurationMs,
            ThroughputPerSecond,
            StartedAtUtc,
            FinishedAtUtc,
            WallClockMs,
            SqlProductVersion,
            SqlProductLevel,
            SqlEdition,
            SqlEngineEdition,
            SqlInstanceName,
            SqlCompatibilityLevel
        FROM dbo.StressRun
        WHERE RunId = @RunId;
        """;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@RunId", runId);

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            return null;

        return MapRun(reader);
    }

    public async Task<StressRunRecord?> GetLatestRunByProfileAsync(
        string profileName,
        string excludeRunId,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT TOP (1)
            RunId,
            ProfileName,
            ScenarioName,
            TagsCsv,
            EnvironmentName,
            MachineName,
            OsVersion,
            DotNetVersion,
            ServerName,
            DatabaseName,
            CommandType,
            ExecutionMode,
            Workers,
            IterationsPerWorker,
            TotalExecutions,
            SuccessCount,
            ErrorCount,
            RetryCount,
            AvgDurationMs,
            MinDurationMs,
            P50DurationMs,
            P95DurationMs,
            P99DurationMs,
            MaxDurationMs,
            ThroughputPerSecond,
            StartedAtUtc,
            FinishedAtUtc,
            WallClockMs,
            SqlProductVersion,
            SqlProductLevel,
            SqlEdition,
            SqlEngineEdition,
            SqlInstanceName,
            SqlCompatibilityLevel
        FROM dbo.StressRun
        WHERE ProfileName = @ProfileName
          AND RunId <> @ExcludeRunId
        ORDER BY StartedAtUtc DESC;
        """;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@ProfileName", profileName);
        cmd.Parameters.AddWithValue("@ExcludeRunId", excludeRunId);

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        if (!await reader.ReadAsync(cancellationToken))
            return null;

        return MapRun(reader);
    }

    public async Task<List<StressRunRecord>> GetLatestRunsByProfileAsync(
        string profileName,
        int top,
        CancellationToken cancellationToken = default)
    {
        const string sql = """
        SELECT TOP (@Top)
            RunId,
            ProfileName,
            ScenarioName,
            TagsCsv,
            EnvironmentName,
            MachineName,
            OsVersion,
            DotNetVersion,
            ServerName,
            DatabaseName,
            CommandType,
            ExecutionMode,
            Workers,
            IterationsPerWorker,
            TotalExecutions,
            SuccessCount,
            ErrorCount,
            RetryCount,
            AvgDurationMs,
            MinDurationMs,
            P50DurationMs,
            P95DurationMs,
            P99DurationMs,
            MaxDurationMs,
            ThroughputPerSecond,
            StartedAtUtc,
            FinishedAtUtc,
            WallClockMs,
            SqlProductVersion,
            SqlProductLevel,
            SqlEdition,
            SqlEngineEdition,
            SqlInstanceName,
            SqlCompatibilityLevel
        FROM dbo.StressRun
        WHERE ProfileName = @ProfileName
        ORDER BY StartedAtUtc DESC;
        """;

        var result = new List<StressRunRecord>();

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Top", top);
        cmd.Parameters.AddWithValue("@ProfileName", profileName);

        await using var reader = await cmd.ExecuteReaderAsync(cancellationToken);

        while (await reader.ReadAsync(cancellationToken))
        {
            result.Add(MapRun(reader));
        }

        return result;
    }

    private static StressRunRecord MapRun(SqlDataReader reader)
    {
        return new StressRunRecord
        {
            RunId = reader["RunId"]?.ToString() ?? "",
            ProfileName = reader["ProfileName"]?.ToString() ?? "",
            ScenarioName = reader["ScenarioName"]?.ToString() ?? "",
            TagsCsv = reader["TagsCsv"]?.ToString() ?? "",
            EnvironmentName = reader["EnvironmentName"]?.ToString() ?? "",
            MachineName = reader["MachineName"]?.ToString() ?? "",
            OsVersion = reader["OsVersion"]?.ToString() ?? "",
            DotNetVersion = reader["DotNetVersion"]?.ToString() ?? "",
            ServerName = reader["ServerName"]?.ToString() ?? "",
            DatabaseName = reader["DatabaseName"]?.ToString() ?? "",
            CommandType = reader["CommandType"]?.ToString() ?? "",
            ExecutionMode = reader["ExecutionMode"]?.ToString() ?? "",
            Workers = Convert.ToInt32(reader["Workers"]),
            IterationsPerWorker = Convert.ToInt32(reader["IterationsPerWorker"]),
            TotalExecutions = Convert.ToInt32(reader["TotalExecutions"]),
            SuccessCount = Convert.ToInt32(reader["SuccessCount"]),
            ErrorCount = Convert.ToInt32(reader["ErrorCount"]),
            RetryCount = Convert.ToInt32(reader["RetryCount"]),
            AvgDurationMs = Convert.ToDouble(reader["AvgDurationMs"]),
            MinDurationMs = Convert.ToInt64(reader["MinDurationMs"]),
            P50DurationMs = Convert.ToInt64(reader["P50DurationMs"]),
            P95DurationMs = Convert.ToInt64(reader["P95DurationMs"]),
            P99DurationMs = Convert.ToInt64(reader["P99DurationMs"]),
            MaxDurationMs = Convert.ToInt64(reader["MaxDurationMs"]),
            ThroughputPerSecond = Convert.ToDouble(reader["ThroughputPerSecond"]),
            StartedAtUtc = Convert.ToDateTime(reader["StartedAtUtc"]),
            FinishedAtUtc = Convert.ToDateTime(reader["FinishedAtUtc"]),
            WallClockMs = Convert.ToInt64(reader["WallClockMs"]),
            SqlProductVersion = reader["SqlProductVersion"]?.ToString() ?? "",
            SqlProductLevel = reader["SqlProductLevel"]?.ToString() ?? "",
            SqlEdition = reader["SqlEdition"]?.ToString() ?? "",
            SqlEngineEdition = reader["SqlEngineEdition"]?.ToString() ?? "",
            SqlInstanceName = reader["SqlInstanceName"]?.ToString() ?? "",
            SqlCompatibilityLevel = reader["SqlCompatibilityLevel"] == DBNull.Value
                ? 0
                : Convert.ToInt32(reader["SqlCompatibilityLevel"])
        };
    }

}