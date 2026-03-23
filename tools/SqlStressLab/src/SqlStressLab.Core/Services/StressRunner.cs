using System.Collections.Concurrent;
using System.Data;
using System.Diagnostics;
using System.Globalization;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;
using System.Text.Json;

namespace SqlStressLab.Core.Services;

public sealed class StressRunner
{
    public async Task<StressRunResult> RunAsync(
        StressOptions options,
        RetryOptions retryOptions,
        List<WorkerAssignment> workerAssignments,
        IProgress<ProgressSnapshot>? progress = null,
        CancellationToken cancellationToken = default)
    {
        if (options.Workers <= 0)
            throw new InvalidOperationException("Workers musi być > 0.");

        if (options.IterationsPerWorker <= 0)
            throw new InvalidOperationException("IterationsPerWorker musi być > 0.");

        var runId = GenerateRunId();
        var startedAtUtc = DateTime.UtcNow;

        var samples = new ConcurrentBag<ExecutionSample>();

        var totalPlannedExecutions = options.Workers * options.IterationsPerWorker;

        var progressState = new ProgressState
        {
            RunId = runId,
            TotalPlannedExecutions = totalPlannedExecutions
        };

        var tasks = new List<Task>(options.Workers);

        for (int workerId = 1; workerId <= options.Workers; workerId++)
        {
            var localWorkerId = workerId;

            tasks.Add(Task.Run(async () =>
            {
                var assignment = workerAssignments.FirstOrDefault(x => x.WorkerId == localWorkerId);
                var workerOptions = ResolveWorkerOptions(options, assignment);

                await RunWorkerAsync(
                    localWorkerId,
                    workerOptions,
                    retryOptions,
                    runId,
                    samples,
                    progressState,
                    progress,
                    cancellationToken);
            }, cancellationToken));
        }

        await Task.WhenAll(tasks);

        var finishedAtUtc = DateTime.UtcNow;

        var orderedSamples = samples
            .OrderBy(x => x.StartedAtUtc)
            .ThenBy(x => x.WorkerId)
            .ThenBy(x => x.Iteration)
            .ToList();

        var summary = BuildSummary(orderedSamples, startedAtUtc, finishedAtUtc);

        return new StressRunResult
        {
            RunId = runId,
            StartedAtUtc = startedAtUtc,
            FinishedAtUtc = finishedAtUtc,
            RetryCount = progressState.RetryCount,
            Samples = orderedSamples,
            Summary = summary
        };
    }

    private async Task RunWorkerAsync(
        int workerId,
        StressOptions options,
        RetryOptions retryOptions,
        string runId,
        ConcurrentBag<ExecutionSample> samples,
        ProgressState progressState,
        IProgress<ProgressSnapshot>? progress,
        CancellationToken cancellationToken)
    {
        var connectionString = ConnectionStringFactory.Build(options.Connection);

        await using var connection = new SqlConnection(connectionString);
        await connection.OpenAsync(cancellationToken);

        if (!string.IsNullOrWhiteSpace(options.SessionSettingsFile))
        {
            await ApplySessionSettingsAsync(
                connection,
                options.SessionSettingsFile!,
                options.CommandTimeoutSeconds,
                cancellationToken);
        }

        var sessionInfo = await SessionContextLoader.LoadAsync(connection, cancellationToken);

        if (options.WarmupEnabled && options.WarmupIterationsPerWorker > 0)
        {
            for (int warmup = 1; warmup <= options.WarmupIterationsPerWorker; warmup++)
            {
                cancellationToken.ThrowIfCancellationRequested();

                try
                {
                    await ExecuteOneAsync(
                        connection,
                        options,
                        retryOptions,
                        sessionInfo,
                        workerId,
                        iteration: 0,
                        collectResult: false,
                        progressState,
                        cancellationToken);
                }
                catch
                {
                    // Warmup nie rozwala całego runu.
                    // To świadoma decyzja dla labów/demo.
                }
            }
        }

        for (int iteration = 1; iteration <= options.IterationsPerWorker; iteration++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            var sample = await ExecuteOneAsync(
                connection,
                options,
                retryOptions,
                sessionInfo,
                workerId,
                iteration,
                collectResult: true,
                progressState,
                cancellationToken);

            samples.Add(sample);

            Interlocked.Increment(ref progressState.CompletedExecutions);

            if (sample.Success)
                Interlocked.Increment(ref progressState.SuccessCount);
            else
                Interlocked.Increment(ref progressState.ErrorCount);

            progress?.Report(new ProgressSnapshot
            {
                RunId = runId,
                TotalPlannedExecutions = progressState.TotalPlannedExecutions,
                CompletedExecutions = progressState.CompletedExecutions,
                SuccessCount = progressState.SuccessCount,
                ErrorCount = progressState.ErrorCount,
                RetryCount = progressState.RetryCount
            });

            if ((options.DelayBetweenIterationsMs ??0) > 0)
            {
                await Task.Delay(options.DelayBetweenIterationsMs ?? 0, cancellationToken);
            }
        }
    }

    private async Task<ExecutionSample> ExecuteOneAsync(
        SqlConnection connection,
        StressOptions options,
        RetryOptions retryOptions,
        SessionInfo sessionInfo,
        int workerId,
        int iteration,
        bool collectResult,
        ProgressState progressState,
        CancellationToken cancellationToken)
    {
        var sample = new ExecutionSample
        {
            WorkerId = workerId,
            Iteration = iteration,
            StartedAtUtc = DateTime.UtcNow,
            Spid = sessionInfo.Spid,
            HostName = sessionInfo.HostName,
            AppName = sessionInfo.AppName,
            LoginName = sessionInfo.LoginName,
            DatabaseName = sessionInfo.DatabaseName
        };

        var maxAttempts = retryOptions.Enabled
            ? Math.Max(1, retryOptions.MaxRetries + 1)
            : 1;

        Exception? lastException = null;

        for (int attempt = 1; attempt <= maxAttempts; attempt++)
        {
            cancellationToken.ThrowIfCancellationRequested();

            sample.RetryAttempt = attempt - 1;

            var sw = Stopwatch.StartNew();

            try
            {
                await using var command = BuildCommand(connection, options, workerId, iteration);

                if (options.UseTransaction)
                {
                    await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
                    command.Transaction = (SqlTransaction)transaction;

                    await ExecuteCommandByModeAsync(command, options.ExecutionMode, sample, cancellationToken);

                    await transaction.CommitAsync(cancellationToken);
                }
                else
                {
                    await ExecuteCommandByModeAsync(command, options.ExecutionMode, sample, cancellationToken);
                }

                sw.Stop();

                if (collectResult)
                {
                    sample.DurationMs = sw.ElapsedMilliseconds;
                    sample.Success = true;
                    sample.ErrorCategory = null;
                    sample.SqlErrorNumber = null;
                    sample.ErrorMessage = null;
                }

                return sample;
            }
            catch (SqlException ex) when (ShouldRetrySqlException(ex, retryOptions, attempt, maxAttempts))
            {
                sw.Stop();
                lastException = ex;
                Interlocked.Increment(ref progressState.RetryCount);

                if (retryOptions.DelayMs > 0)
                    await Task.Delay(retryOptions.DelayMs, cancellationToken);
            }
            catch (SqlException ex)
            {
                sw.Stop();

                if (collectResult)
                {
                    sample.DurationMs = sw.ElapsedMilliseconds;
                    sample.Success = false;
                    sample.ErrorCategory = "SqlError";
                    sample.SqlErrorNumber = ex.Number;
                    sample.ErrorMessage = ex.Message;
                }

                return sample;
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex) when (ShouldRetryGenericException(ex, retryOptions, attempt, maxAttempts))
            {
                sw.Stop();
                lastException = ex;
                Interlocked.Increment(ref progressState.RetryCount);

                if (retryOptions.DelayMs > 0)
                    await Task.Delay(retryOptions.DelayMs, cancellationToken);
            }
            catch (Exception ex)
            {
                sw.Stop();

                if (collectResult)
                {
                    sample.DurationMs = sw.ElapsedMilliseconds;
                    sample.Success = false;
                    sample.ErrorCategory = "Unhandled";
                    sample.SqlErrorNumber = null;
                    sample.ErrorMessage = ex.Message;
                }

                return sample;
            }
        }

        if (collectResult)
        {
            sample.Success = false;
            sample.ErrorCategory = ClassifyException(lastException);
            sample.SqlErrorNumber = lastException is SqlException sqlEx ? sqlEx.Number : null;
            sample.ErrorMessage = lastException?.Message ?? "Unknown error after retries";
        }

        return sample;
    }

    private static SqlCommand BuildCommand(
        SqlConnection connection,
        StressOptions options,
        int workerId,
        int iteration)
    {
        var command = connection.CreateCommand();
        command.CommandText = options.CommandText;
        command.CommandTimeout = options.CommandTimeoutSeconds;
        command.CommandType = ParseCommandType(options.CommandType);

        foreach (var parameter in options.Parameters)
        {
            var sqlParameter = BuildParameter(parameter, workerId, iteration);
            command.Parameters.Add(sqlParameter);
        }

        return command;
    }

    private static async Task ExecuteCommandByModeAsync(
        SqlCommand command,
        string executionMode,
        ExecutionSample sample,
        CancellationToken cancellationToken)
    {
        switch (executionMode.Trim().ToLowerInvariant())
        {
            case "nonquery":
                await command.ExecuteNonQueryAsync(cancellationToken);
                break;

            case "scalar":
                var scalar = await command.ExecuteScalarAsync(cancellationToken);
                sample.ScalarValue = scalar?.ToString();
                break;

            case "reader":
                await using (var reader = await command.ExecuteReaderAsync(cancellationToken))
                {
                    int rowCount = 0;
                    var previewRows = new List<Dictionary<string, object?>>();

                    while (await reader.ReadAsync(cancellationToken))
                    {
                        rowCount++;

                        if (previewRows.Count < 5)
                        {
                            var row = new Dictionary<string, object?>(StringComparer.OrdinalIgnoreCase);

                            for (int i = 0; i < reader.FieldCount; i++)
                            {
                                row[reader.GetName(i)] = await reader.IsDBNullAsync(i, cancellationToken)
                                    ? null
                                    : reader.GetValue(i);
                            }

                            previewRows.Add(row);
                        }
                    }

                    sample.ReaderRowCount = rowCount;

                    if (previewRows.Count > 0)
                    {
                        sample.ReaderPreviewJson = JsonSerializer.Serialize(previewRows);
                    }
                }
                break;

            default:
                throw new InvalidOperationException($"Nieznany executionMode: {executionMode}");
        }
    }

    private static SqlParameter BuildParameter(SqlParameterDefinition definition, int workerId, int iteration)
    {
        var parameterName = definition.Name.StartsWith("@", StringComparison.Ordinal)
            ? definition.Name
            : "@" + definition.Name;

        object? value = ResolveParameterValue(definition, workerId, iteration);

        var parameter = new SqlParameter(parameterName, ParseSqlDbType(definition.Type))
        {
            Value = value ?? DBNull.Value
        };

        return parameter;
    }

    private static object? ResolveParameterValue(SqlParameterDefinition definition, int workerId, int iteration)
    {
        var mode = definition.Mode?.Trim().ToLowerInvariant() ?? "fixed";

        switch (mode)
        {
            case "fixed":
                return ConvertValue(definition.Type, definition.Value);

            case "workerid":
                return ConvertValue(definition.Type, workerId.ToString(CultureInfo.InvariantCulture));

            case "iteration":
                return ConvertValue(definition.Type, iteration.ToString(CultureInfo.InvariantCulture));

            case "randomintrange":
                var min = int.Parse(definition.Min ?? "1", CultureInfo.InvariantCulture);
                var max = int.Parse(definition.Max ?? "100", CultureInfo.InvariantCulture);
                return Random.Shared.Next(min, max + 1);

            case "sequence":
                var start = int.Parse(definition.Start ?? "1", CultureInfo.InvariantCulture);
                var increment = int.Parse(definition.Increment ?? "1", CultureInfo.InvariantCulture);
                var sequenceValue = start + ((iteration - 1) * increment);
                return ConvertValue(definition.Type, sequenceValue.ToString(CultureInfo.InvariantCulture));

            default:
                throw new InvalidOperationException($"Nieznany parameter mode: {definition.Mode}");
        }
    }

    private static object? ConvertValue(string type, string? value)
    {
        if (value is null)
            return null;

        switch (type.Trim().ToUpperInvariant())
        {
            case "INT":
                return int.Parse(value, CultureInfo.InvariantCulture);

            case "BIGINT":
                return long.Parse(value, CultureInfo.InvariantCulture);

            case "BIT":
                return bool.Parse(value);

            case "DECIMAL":
            case "NUMERIC":
                return decimal.Parse(value, CultureInfo.InvariantCulture);

            case "FLOAT":
                return double.Parse(value, CultureInfo.InvariantCulture);

            case "UNIQUEIDENTIFIER":
                return Guid.Parse(value);

            case "DATETIME":
            case "DATETIME2":
                return DateTime.Parse(value, CultureInfo.InvariantCulture);

            case "NVARCHAR":
            case "VARCHAR":
            case "NCHAR":
            case "CHAR":
            case "TEXT":
            case "NTEXT":
            default:
                return value;
        }
    }

    private static SqlDbType ParseSqlDbType(string type)
    {
        switch (type.Trim().ToUpperInvariant())
        {
            case "INT": return SqlDbType.Int;
            case "BIGINT": return SqlDbType.BigInt;
            case "BIT": return SqlDbType.Bit;
            case "DECIMAL": return SqlDbType.Decimal;
            case "NUMERIC": return SqlDbType.Decimal;
            case "FLOAT": return SqlDbType.Float;
            case "UNIQUEIDENTIFIER": return SqlDbType.UniqueIdentifier;
            case "DATETIME": return SqlDbType.DateTime;
            case "DATETIME2": return SqlDbType.DateTime2;
            case "VARCHAR": return SqlDbType.VarChar;
            case "CHAR": return SqlDbType.Char;
            case "NCHAR": return SqlDbType.NChar;
            case "TEXT": return SqlDbType.Text;
            case "NTEXT": return SqlDbType.NText;
            case "NVARCHAR":
            default:
                return SqlDbType.NVarChar;
        }
    }

    private static CommandType ParseCommandType(string commandType)
    {
        return commandType.Trim().ToLowerInvariant() switch
        {
            "storedprocedure" => CommandType.StoredProcedure,
            "text" => CommandType.Text,
            _ => throw new InvalidOperationException($"Nieznany commandType: {commandType}")
        };
    }

    private static bool ShouldRetrySqlException(
        SqlException ex,
        RetryOptions retryOptions,
        int attempt,
        int maxAttempts)
    {
        if (!retryOptions.Enabled)
            return false;

        if (attempt >= maxAttempts)
            return false;

        return retryOptions.RetryableSqlErrorNumbers.Contains(ex.Number);
    }

    private static bool ShouldRetryGenericException(
        Exception ex,
        RetryOptions retryOptions,
        int attempt,
        int maxAttempts)
    {
        if (!retryOptions.Enabled)
            return false;

        if (attempt >= maxAttempts)
            return false;

        return ex is TimeoutException;
    }

    private static string ClassifyException(Exception? ex)
    {
        if (ex is null)
            return "Unknown";

        if (ex is SqlException sqlEx)
        {
            return sqlEx.Number switch
            {
                -2 => "Timeout",
                1205 => "Deadlock",
                _ => "SqlError"
            };
        }

        if (ex is TimeoutException)
            return "Timeout";

        return "Unhandled";
    }

    private static async Task ApplySessionSettingsAsync(
        SqlConnection connection,
        string settingsFile,
        int commandTimeoutSeconds,
        CancellationToken cancellationToken)
    {
        if (!File.Exists(settingsFile))
            throw new FileNotFoundException($"Nie znaleziono pliku ustawień sesji: {settingsFile}");

        var sql = await File.ReadAllTextAsync(settingsFile, cancellationToken);

        if (string.IsNullOrWhiteSpace(sql))
            return;

        await using var command = connection.CreateCommand();
        command.CommandText = sql;
        command.CommandType = CommandType.Text;
        command.CommandTimeout = commandTimeoutSeconds;

        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private static StressOptions ResolveWorkerOptions(StressOptions baseOptions, WorkerAssignment? assignment)
    {
        if (assignment is null)
            return baseOptions;

        return new StressOptions
        {
            Connection = baseOptions.Connection,
            CommandText = string.IsNullOrWhiteSpace(assignment.CommandTextOverride)
                ? baseOptions.CommandText
                : assignment.CommandTextOverride,
            CommandType = string.IsNullOrWhiteSpace(assignment.CommandTypeOverride)
                ? baseOptions.CommandType
                : assignment.CommandTypeOverride,
            ExecutionMode = baseOptions.ExecutionMode,
            Workers = baseOptions.Workers,
            IterationsPerWorker = baseOptions.IterationsPerWorker,
            CommandTimeoutSeconds = baseOptions.CommandTimeoutSeconds,
            UseTransaction = baseOptions.UseTransaction,
            WarmupEnabled = baseOptions.WarmupEnabled,
            WarmupIterationsPerWorker = baseOptions.WarmupIterationsPerWorker,
            SessionSettingsFile = baseOptions.SessionSettingsFile,
            DelayBetweenIterationsMs = baseOptions.DelayBetweenIterationsMs,
            Parameters = baseOptions.Parameters
        };
    }

    private static StressSummary BuildSummary(
        List<ExecutionSample> samples,
        DateTime startedAtUtc,
        DateTime finishedAtUtc)
    {
        var successSamples = samples
            .Where(x => x.Success)
            .Select(x => x.DurationMs)
            .OrderBy(x => x)
            .ToList();

        var totalExecutions = samples.Count;
        var successCount = samples.Count(x => x.Success);
        var errorCount = totalExecutions - successCount;

        var wallClockSeconds = Math.Max(1.0, (finishedAtUtc - startedAtUtc).TotalSeconds);

        if (successSamples.Count == 0)
        {
            return new StressSummary
            {
                TotalExecutions = totalExecutions,
                SuccessCount = successCount,
                ErrorCount = errorCount,
                AvgDurationMs = 0,
                MinDurationMs = 0,
                P50DurationMs = 0,
                P95DurationMs = 0,
                P99DurationMs = 0,
                MaxDurationMs = 0,
                ThroughputPerSecond = 0
            };
        }

        return new StressSummary
        {
            TotalExecutions = totalExecutions,
            SuccessCount = successCount,
            ErrorCount = errorCount,
            AvgDurationMs = successSamples.Average(),
            MinDurationMs = successSamples.First(),
            P50DurationMs = Percentile(successSamples, 0.50),
            P95DurationMs = Percentile(successSamples, 0.95),
            P99DurationMs = Percentile(successSamples, 0.99),
            MaxDurationMs = successSamples.Last(),
            ThroughputPerSecond = successCount / wallClockSeconds
        };
    }

    private static long Percentile(List<long> orderedValues, double percentile)
    {
        if (orderedValues.Count == 0)
            return 0;

        if (orderedValues.Count == 1)
            return orderedValues[0];

        var index = (int)Math.Ceiling(percentile * orderedValues.Count) - 1;
        index = Math.Max(0, Math.Min(index, orderedValues.Count - 1));

        return orderedValues[index];
    }

    private static string GenerateRunId()
    {
        return $"RUN_{DateTime.UtcNow:yyyyMMdd_HHmmssfff}";
    }

    private sealed class ProgressState
    {
        public string RunId { get; set; } = "";
        public int TotalPlannedExecutions { get; set; }
        public int CompletedExecutions;
        public int SuccessCount;
        public int ErrorCount;
        public int RetryCount;
    }
}