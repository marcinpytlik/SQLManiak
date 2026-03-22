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

    public async Task InsertRunAsync(StressRunRecord run, CancellationToken cancellationToken = default)
    {
        const string sql = """
        INSERT INTO dbo.StressRun
        (
            RunId, ProfileName, ScenarioName, ServerName, DatabaseName,
            CommandType, ExecutionMode, Workers, IterationsPerWorker,
            TotalExecutions, SuccessCount, ErrorCount, RetryCount,
            AvgDurationMs, MinDurationMs, P50DurationMs, P95DurationMs, P99DurationMs, MaxDurationMs,
            ThroughputPerSecond, StartedAtUtc, FinishedAtUtc, WallClockMs
        )
        VALUES
        (
            @RunId, @ProfileName, @ScenarioName, @ServerName, @DatabaseName,
            @CommandType, @ExecutionMode, @Workers, @IterationsPerWorker,
            @TotalExecutions, @SuccessCount, @ErrorCount, @RetryCount,
            @AvgDurationMs, @MinDurationMs, @P50DurationMs, @P95DurationMs, @P99DurationMs, @MaxDurationMs,
            @ThroughputPerSecond, @StartedAtUtc, @FinishedAtUtc, @WallClockMs
        );
        """;

        await using var conn = new SqlConnection(_connectionString);
        await conn.OpenAsync(cancellationToken);

        await using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@RunId", run.RunId);
        cmd.Parameters.AddWithValue("@ProfileName", run.ProfileName);
        cmd.Parameters.AddWithValue("@ScenarioName", run.ScenarioName);
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

        await cmd.ExecuteNonQueryAsync(cancellationToken);
    }

    public async Task InsertSamplesAsync(IEnumerable<StressRunSampleRecord> samples, CancellationToken cancellationToken = default)
    {
        const string sql = """
        INSERT INTO dbo.StressRunSample
        (
            RunId, WorkerId, Iteration, StartedAtUtc, DurationMs, Success,
            RetryAttempt, ErrorCategory, SqlErrorNumber, ErrorMessage, ScalarValue, ReaderRowCount
        )
        VALUES
        (
            @RunId, @WorkerId, @Iteration, @StartedAtUtc, @DurationMs, @Success,
            @RetryAttempt, @ErrorCategory, @SqlErrorNumber, @ErrorMessage, @ScalarValue, @ReaderRowCount
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

            await cmd.ExecuteNonQueryAsync(cancellationToken);
        }
    }
}