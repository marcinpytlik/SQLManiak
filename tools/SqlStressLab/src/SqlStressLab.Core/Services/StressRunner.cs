using System.Collections.Concurrent;
using System.Diagnostics;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class StressRunner
{
    public async Task<(StressSummary Summary, List<ExecutionSample> Samples)> RunAsync(
        StressOptions options,
        CancellationToken cancellationToken = default)
    {
        var samples = new ConcurrentBag<ExecutionSample>();
        var tasks = new List<Task>();
        var sessionStatements = SessionSettingsLoader.LoadStatements(options.SessionSettingsFile);
        var connectionString = ConnectionStringFactory.Build(options.Connection);

        for (int workerId = 1; workerId <= options.Workers; workerId++)
        {
            var localWorkerId = workerId;
            tasks.Add(Task.Run(() => RunWorkerAsync(
                localWorkerId,
                connectionString,
                options,
                sessionStatements,
                samples,
                cancellationToken), cancellationToken));
        }

        await Task.WhenAll(tasks);

        var ordered = samples
            .OrderBy(x => x.WorkerId)
            .ThenBy(x => x.Iteration)
            .ToList();

        var summary = MetricsCalculator.BuildSummary(ordered);
        return (summary, ordered);
    }

    private static async Task RunWorkerAsync(
        int workerId,
        string connectionString,
        StressOptions options,
        IReadOnlyList<string> sessionStatements,
        ConcurrentBag<ExecutionSample> samples,
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

        if (options.WarmupEnabled && options.WarmupIterationsPerWorker > 0)
        {
            for (int i = 1; i <= options.WarmupIterationsPerWorker; i++)
            {
                await ExecuteSingleAsync(connection, options, workerId, i, collectSample: false, samples, cancellationToken);
            }
        }

        for (int i = 1; i <= options.IterationsPerWorker; i++)
        {
            await ExecuteSingleAsync(connection, options, workerId, i, collectSample: true, samples, cancellationToken);

            if (options.DelayBetweenIterationsMs.HasValue && options.DelayBetweenIterationsMs.Value > 0)
            {
                await Task.Delay(options.DelayBetweenIterationsMs.Value, cancellationToken);
            }
        }
    }

    private static async Task ExecuteSingleAsync(
        SqlConnection connection,
        StressOptions options,
        int workerId,
        int iteration,
        bool collectSample,
        ConcurrentBag<ExecutionSample> samples,
        CancellationToken cancellationToken)
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
                Iteration = iteration,
                StartedAtUtc = started
            };

            await SqlExecutor.ExecuteAsync(connection, tx, options, sample, workerId, iteration, cancellationToken);

            if (tx is not null)
            {
                await tx.CommitAsync(cancellationToken);
            }

            sw.Stop();

            if (collectSample)
            {
                sample.DurationMs = sw.ElapsedMilliseconds;
                sample.Success = true;
                samples.Add(sample);
            }
        }
        catch (SqlException ex)
        {
            sw.Stop();

            if (collectSample)
            {
                samples.Add(new ExecutionSample
                {
                    WorkerId = workerId,
                    Iteration = iteration,
                    StartedAtUtc = started,
                    DurationMs = sw.ElapsedMilliseconds,
                    Success = false,
                    SqlErrorNumber = ex.Number,
                    ErrorCategory = MapSqlError(ex.Number),
                    ErrorMessage = ex.Message
                });
            }
        }
        catch (OperationCanceledException ex)
        {
            sw.Stop();

            if (collectSample)
            {
                samples.Add(new ExecutionSample
                {
                    WorkerId = workerId,
                    Iteration = iteration,
                    StartedAtUtc = started,
                    DurationMs = sw.ElapsedMilliseconds,
                    Success = false,
                    ErrorCategory = "Cancelled",
                    ErrorMessage = ex.Message
                });
            }
        }
        catch (Exception ex)
        {
            sw.Stop();

            if (collectSample)
            {
                samples.Add(new ExecutionSample
                {
                    WorkerId = workerId,
                    Iteration = iteration,
                    StartedAtUtc = started,
                    DurationMs = sw.ElapsedMilliseconds,
                    Success = false,
                    ErrorCategory = "General",
                    ErrorMessage = ex.Message
                });
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