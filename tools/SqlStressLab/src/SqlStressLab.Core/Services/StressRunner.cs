using System.Collections.Concurrent;
using System.Diagnostics;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class StressRunner
{
    public async Task<(StressSummary Summary, List<ExecutionSample> Samples, string RunId, DateTime StartedAtUtc, DateTime FinishedAtUtc, int RetryCount)> RunAsync(
        StressOptions options,
        RetryOptions retryOptions,
        IProgress<ProgressSnapshot>? progress = null,
        CancellationToken cancellationToken = default)
    {
        var runId = $"RUN_{DateTime.UtcNow:yyyyMMdd_HHmmssfff}";
        var startedAtUtc = DateTime.UtcNow;
        var samples = new ConcurrentBag<ExecutionSample>();
        var tasks = new List<Task>();
        var sessionStatements = SessionSettingsLoader.LoadStatements(options.SessionSettingsFile);
        var connectionString = ConnectionStringFactory.Build(options.Connection);
        var tracker = new ProgressTracker(runId, options.Workers * options.IterationsPerWorker);

        for (int workerId = 1; workerId <= options.Workers; workerId++)
        {
            var localWorkerId = workerId;
            tasks.Add(Task.Run(() => RunWorkerAsync(
                localWorkerId,
                connectionString,
                options,
                retryOptions,
                sessionStatements,
                samples,
                tracker,
                progress,
                cancellationToken), cancellationToken));
        }

        await Task.WhenAll(tasks);

        var ordered = samples
            .OrderBy(x => x.WorkerId)
            .ThenBy(x => x.Iteration)
            .ToList();

        var summary = MetricsCalculator.BuildSummary(ordered);
        var finishedAtUtc = DateTime.UtcNow;

        return (summary, ordered, runId, startedAtUtc, finishedAtUtc, tracker.Snapshot.RetryCount);
    }

    private static async Task RunWorkerAsync(
        int workerId,
        string connectionString,
        StressOptions options,
        RetryOptions retryOptions,
        IReadOnlyList<string> sessionStatements,
        ConcurrentBag<ExecutionSample> samples,
        ProgressTracker tracker,
        IProgress<ProgressSnapshot>? progress,
        CancellationToken cancellationToken)
    {
        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        foreach (var stmt in sessionStatements)
        {
            await using var settingsCmd = new SqlCommand(stmt, connection)
            {
                CommandTimeout = options.CommandTimeoutSeconds
            };

            await settingsCmd.ExecuteNonQueryAsync(cancellationToken);
        }

        for (int i = 1; i <= options.IterationsPerWorker; i++)
        {
            int attempt = 0;

            while (true)
            {
                var started = DateTime.UtcNow;
                var sw = Stopwatch.StartNew();

                try
                {
                    await using SqlTransaction? tx = options.UseTransaction
                        ? (SqlTransaction?)await connection.BeginTransactionAsync(cancellationToken)
                        : null;

                    var sample = new ExecutionSample
                    {
                        WorkerId = workerId,
                        Iteration = i,
                        StartedAtUtc = started,
                        RetryAttempt = attempt
                    };

                    await SqlExecutor.ExecuteAsync(connection, tx, options, sample, workerId, i, cancellationToken);

                    if (tx is not null)
                        await tx.CommitAsync(cancellationToken);

                    sw.Stop();

                    sample.DurationMs = sw.ElapsedMilliseconds;
                    sample.Success = true;

                    samples.Add(sample);
                    tracker.MarkSuccess();
                    progress?.Report(tracker.Snapshot);
                    break;
                }
                catch (SqlException ex) when (RetryPolicy.ShouldRetry(ex, retryOptions, attempt))
                {
                    sw.Stop();
                    tracker.MarkRetry();
                    progress?.Report(tracker.Snapshot);

                    attempt++;
                    await Task.Delay(retryOptions.DelayMs, cancellationToken);
                }
                catch (SqlException ex)
                {
                    sw.Stop();

                    samples.Add(new ExecutionSample
                    {
                        WorkerId = workerId,
                        Iteration = i,
                        StartedAtUtc = started,
                        DurationMs = sw.ElapsedMilliseconds,
                        Success = false,
                        RetryAttempt = attempt,
                        SqlErrorNumber = ex.Number,
                        ErrorCategory = MapSqlError(ex.Number),
                        ErrorMessage = ex.Message
                    });

                    tracker.MarkError();
                    progress?.Report(tracker.Snapshot);
                    break;
                }
            }
        }
    }

    private static string MapSqlError(int errorNumber)
        => errorNumber switch
        {
            1205 => "Deadlock",
            -2 => "Timeout",
            18456 => "LoginFailed",
            _ => "SqlError"
        };
}