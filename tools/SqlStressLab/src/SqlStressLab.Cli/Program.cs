using System.Text.Json;
using SqlStressLab.Core.Models;
using SqlStressLab.Core.Services;

var cts = new CancellationTokenSource();

Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    cts.Cancel();
};

try
{
    // ------------------------------------------------------------
    // 1. PROFILE PATH
    // ------------------------------------------------------------
    var profilePath = args.Length > 0
        ? args[0]
        : Path.Combine("profiles", "demo-select.json");

    var fullProfilePath = Path.GetFullPath(profilePath);

    if (!File.Exists(fullProfilePath))
    {
        Console.WriteLine($"Brak pliku profilu: {fullProfilePath}");
        return 1;
    }

    var profileDirectory = Path.GetDirectoryName(fullProfilePath)
                           ?? Directory.GetCurrentDirectory();

    // ------------------------------------------------------------
    // 2. LOAD CONFIG
    // ------------------------------------------------------------
    var json = await File.ReadAllTextAsync(fullProfilePath, cts.Token);

    var config = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true
    });

    if (config is null)
    {
        Console.WriteLine("Nie udało się zdeserializować konfiguracji.");
        return 2;
    }

    // ------------------------------------------------------------
    // 3. RESOLVE PASSWORD FROM ENV
    // ------------------------------------------------------------
    ResolvePasswordFromEnvironment(config.Connection);

    // ------------------------------------------------------------
    // 4. RESOLVE RELATIVE PATHS
    //    Wszystkie ścieżki względne liczymy względem katalogu profilu.
    // ------------------------------------------------------------
    config.Execution.SessionSettingsFile =
        ResolvePath(config.Execution.SessionSettingsFile, profileDirectory);

    config.Output.Directory =
        ResolvePath(config.Output.Directory, profileDirectory) ?? "outputs";

    if (config.SqlOutput.Enabled &&
        string.Equals(config.SqlOutput.ConnectionMode, "Separate", StringComparison.OrdinalIgnoreCase) &&
        config.SqlOutput.Connection is not null)
    {
        ResolvePasswordFromEnvironment(config.SqlOutput.Connection);
    }

    // ------------------------------------------------------------
    // 5. BUILD STRESS OPTIONS
    // ------------------------------------------------------------
    var options = new StressOptions
    {
        Connection = config.Connection,
        CommandText = config.Execution.CommandText,
        CommandType = config.Execution.CommandType,
        ExecutionMode = config.Execution.ExecutionMode,
        Workers = config.Execution.Workers,
        IterationsPerWorker = config.Execution.IterationsPerWorker,
        CommandTimeoutSeconds = config.Execution.CommandTimeoutSeconds,
        UseTransaction = config.Execution.UseTransaction,
        WarmupEnabled = config.Execution.WarmupEnabled,
        WarmupIterationsPerWorker = config.Execution.WarmupIterationsPerWorker,
        SessionSettingsFile = config.Execution.SessionSettingsFile,
        DelayBetweenIterationsMs = config.Execution.DelayBetweenIterationsMs,
        Parameters = config.Parameters ?? new()
    };

    // ------------------------------------------------------------
    // 6. HEADER
    // ------------------------------------------------------------
    Console.WriteLine("=== SQL STRESS LAB ===");
    Console.WriteLine($"Profile        : {fullProfilePath}");
    Console.WriteLine($"Server         : {config.Connection.Server}");
    Console.WriteLine($"Database       : {config.Connection.Database}");
    Console.WriteLine($"Authentication : {config.Connection.Authentication}");
    Console.WriteLine($"Workers        : {options.Workers}");
    Console.WriteLine($"Iterations     : {options.IterationsPerWorker}");
    Console.WriteLine($"CommandType    : {options.CommandType}");
    Console.WriteLine($"ExecutionMode  : {options.ExecutionMode}");
    Console.WriteLine($"Session SET    : {options.SessionSettingsFile}");
    Console.WriteLine($"Output Dir     : {config.Output.Directory}");
    Console.WriteLine();

    // ------------------------------------------------------------
    // 7. LIVE PROGRESS
    // ------------------------------------------------------------
    var progress = new Progress<ProgressSnapshot>(snapshot =>
    {
        Console.WriteLine(
            $"[{DateTime.Now:HH:mm:ss}] " +
            $"RunId={snapshot.RunId} " +
            $"Progress={snapshot.CompletedExecutions}/{snapshot.TotalPlannedExecutions} " +
            $"Success={snapshot.SuccessCount} " +
            $"Errors={snapshot.ErrorCount} " +
            $"Retries={snapshot.RetryCount}");
    });

    // ------------------------------------------------------------
    // 8. RUN
    // ------------------------------------------------------------
    var runner = new StressRunner();

    var result = await runner.RunAsync(
        options,
        config.Retry,
        progress,
        cts.Token);

    var summary = result.Summary;
    var samples = result.Samples;
    var runId = result.RunId;
    var startedAtUtc = result.StartedAtUtc;
    var finishedAtUtc = result.FinishedAtUtc;
    var retryCount = result.RetryCount;

    var wallClock = finishedAtUtc - startedAtUtc;
    var wallClockSeconds = wallClock.TotalSeconds <= 0 ? 1 : wallClock.TotalSeconds;
    var realThroughput = summary.SuccessCount / wallClockSeconds;

    // ------------------------------------------------------------
    // 9. CONSOLE SUMMARY
    // ------------------------------------------------------------
    Console.WriteLine();
    Console.WriteLine("=== PODSUMOWANIE ===");
    Console.WriteLine($"RunId             : {runId}");
    Console.WriteLine($"TotalExecutions   : {summary.TotalExecutions}");
    Console.WriteLine($"SuccessCount      : {summary.SuccessCount}");
    Console.WriteLine($"ErrorCount        : {summary.ErrorCount}");
    Console.WriteLine($"RetryCount        : {retryCount}");
    Console.WriteLine($"AvgDurationMs     : {summary.AvgDurationMs:F2}");
    Console.WriteLine($"MinDurationMs     : {summary.MinDurationMs}");
    Console.WriteLine($"P50DurationMs     : {summary.P50DurationMs}");
    Console.WriteLine($"P95DurationMs     : {summary.P95DurationMs}");
    Console.WriteLine($"P99DurationMs     : {summary.P99DurationMs}");
    Console.WriteLine($"MaxDurationMs     : {summary.MaxDurationMs}");
    Console.WriteLine($"Throughput/s(calc): {summary.ThroughputPerSecond:F2}");
    Console.WriteLine($"Throughput/s(real): {realThroughput:F2}");
    Console.WriteLine($"WallClock         : {wallClock}");
    Console.WriteLine();

    var errors = samples
        .Where(x => !x.Success)
        .GroupBy(x => new { x.ErrorCategory, x.SqlErrorNumber })
        .Select(g => new
        {
            g.Key.ErrorCategory,
            g.Key.SqlErrorNumber,
            Count = g.Count()
        })
        .OrderByDescending(x => x.Count)
        .ToList();

    if (errors.Count > 0)
    {
        Console.WriteLine("=== BŁĘDY ===");
        foreach (var err in errors)
        {
            Console.WriteLine(
                $"{err.ErrorCategory ?? "Unknown"} " +
                $"(SqlError={err.SqlErrorNumber?.ToString() ?? "n/a"}): {err.Count}");
        }
        Console.WriteLine();
    }

    // ------------------------------------------------------------
    // 10. WRITE FILE OUTPUTS
    // ------------------------------------------------------------
    if (config.Output.WriteJson)
    {
        await ReportWriter.WriteJsonAsync(config.Output.Directory, summary, samples);
    }

    if (config.Output.WriteCsv)
    {
        await ReportWriter.WriteCsvAsync(config.Output.Directory, samples);
    }

    if (config.Output.WriteReaderPreview)
    {
        await ReportWriter.WriteReaderPreviewAsync(config.Output.Directory, samples);
    }

    // ------------------------------------------------------------
    // 11. OPTIONAL SQL OUTPUT
    // ------------------------------------------------------------
    if (config.SqlOutput.Enabled)
    {
        var sqlOutputConnectionString =
            string.Equals(config.SqlOutput.ConnectionMode, "Separate", StringComparison.OrdinalIgnoreCase)
            && config.SqlOutput.Connection is not null
                ? ConnectionStringFactory.Build(config.SqlOutput.Connection)
                : ConnectionStringFactory.Build(config.Connection);

        var repository = new SqlResultRepository(sqlOutputConnectionString);

        var runRecord = new StressRunRecord
        {
            RunId = runId,
            ProfileName = config.ProfileName,
            ScenarioName = config.ScenarioName,
            ServerName = config.Connection.Server,
            DatabaseName = config.Connection.Database,
            CommandType = options.CommandType,
            ExecutionMode = options.ExecutionMode,
            Workers = options.Workers,
            IterationsPerWorker = options.IterationsPerWorker,
            TotalExecutions = summary.TotalExecutions,
            SuccessCount = summary.SuccessCount,
            ErrorCount = summary.ErrorCount,
            RetryCount = retryCount,
            AvgDurationMs = summary.AvgDurationMs,
            MinDurationMs = summary.MinDurationMs,
            P50DurationMs = summary.P50DurationMs,
            P95DurationMs = summary.P95DurationMs,
            P99DurationMs = summary.P99DurationMs,
            MaxDurationMs = summary.MaxDurationMs,
            ThroughputPerSecond = realThroughput,
            StartedAtUtc = startedAtUtc,
            FinishedAtUtc = finishedAtUtc,
            WallClockMs = (long)wallClock.TotalMilliseconds
        };

        await repository.InsertRunAsync(runRecord, cts.Token);

        var sampleRecords = samples.Select(s => new StressRunSampleRecord
        {
            RunId = runId,
            WorkerId = s.WorkerId,
            Iteration = s.Iteration,
            StartedAtUtc = s.StartedAtUtc,
            DurationMs = s.DurationMs,
            Success = s.Success,
            RetryAttempt = s.RetryAttempt,
            ErrorCategory = s.ErrorCategory,
            SqlErrorNumber = s.SqlErrorNumber,
            ErrorMessage = s.ErrorMessage,
            ScalarValue = s.ScalarValue,
            ReaderRowCount = s.ReaderRowCount
        }).ToList();

        await repository.InsertSamplesAsync(sampleRecords, cts.Token);

        Console.WriteLine("Wyniki zapisane również do SQL Server.");
    }

    Console.WriteLine($"Raport zapisany do: {config.Output.Directory}");
    return 0;
}
catch (OperationCanceledException)
{
    Console.WriteLine("Anulowano.");
    return 10;
}
catch (Exception ex)
{
    Console.WriteLine("Błąd krytyczny:");
    Console.WriteLine(ex.Message);
    return 99;
}

// ============================================================================
// HELPERS
// ============================================================================

static void ResolvePasswordFromEnvironment(SqlAuthOptions connection)
{
    if (!string.Equals(connection.Authentication, "SqlPassword", StringComparison.OrdinalIgnoreCase))
        return;

    if (!string.IsNullOrWhiteSpace(connection.Password))
        return;

    var envPassword = Environment.GetEnvironmentVariable("SQLSTRESSLAB_PASSWORD");

    if (!string.IsNullOrWhiteSpace(envPassword))
    {
        connection.Password = envPassword;
    }
}

static string? ResolvePath(string? path, string baseDirectory)
{
    if (string.IsNullOrWhiteSpace(path))
        return path;

    if (Path.IsPathRooted(path))
        return path;

    return Path.GetFullPath(Path.Combine(baseDirectory, path));
}