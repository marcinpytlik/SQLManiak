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
    // ============================================================
    // 1. PROFILE PATH
    // ============================================================
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

    // ============================================================
    // 2. LOAD CONFIG
    // ============================================================
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

    // ============================================================
    // 3. RESOLVE SECRETS
    // ============================================================
    ResolvePasswordFromEnvironment(config.Connection);

    if (config.SqlOutput.Enabled &&
        string.Equals(config.SqlOutput.ConnectionMode, "Separate", StringComparison.OrdinalIgnoreCase) &&
        config.SqlOutput.Connection is not null)
    {
        ResolvePasswordFromEnvironment(config.SqlOutput.Connection);
    }

    // ============================================================
    // 4. RESOLVE RELATIVE PATHS
    // ============================================================
    config.Execution.SessionSettingsFile =
        ResolvePath(config.Execution.SessionSettingsFile, profileDirectory);

    config.Output.Directory =
        ResolvePath(config.Output.Directory, profileDirectory) ?? Path.Combine(profileDirectory, "outputs");

    config.Lifecycle.SetupScriptFile =
        ResolvePath(config.Lifecycle.SetupScriptFile, profileDirectory);

    config.Lifecycle.CleanupScriptFile =
        ResolvePath(config.Lifecycle.CleanupScriptFile, profileDirectory);

    config.MarkdownReport.Directory =
        ResolvePath(config.MarkdownReport.Directory, profileDirectory) ?? config.Output.Directory;

    config.HtmlReport.Directory =
        ResolvePath(config.HtmlReport.Directory, profileDirectory) ?? config.Output.Directory;

    // ============================================================
    // 5. BUILD STRESS OPTIONS
    // ============================================================
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

    // ============================================================
    // 6. CONNECTION STRINGS
    // ============================================================
    var targetConnectionString = ConnectionStringFactory.Build(config.Connection);

    var sqlOutputConnectionString =
        config.SqlOutput.Enabled &&
        string.Equals(config.SqlOutput.ConnectionMode, "Separate", StringComparison.OrdinalIgnoreCase) &&
        config.SqlOutput.Connection is not null
            ? ConnectionStringFactory.Build(config.SqlOutput.Connection)
            : targetConnectionString;

    // ============================================================
    // 7. ENVIRONMENT INFO
    // ============================================================
    var collectedEnvironment = EnvironmentCollector.Collect(config.Environment);

    // ============================================================
    // 8. SCENARIO PLAN
    // ============================================================
    var scenarioPlan = ScenarioPlanner.Build(config);

    scenarioPlan.EffectiveSetupScriptFile =
        ResolvePath(scenarioPlan.EffectiveSetupScriptFile, profileDirectory);

    scenarioPlan.EffectiveCleanupScriptFile =
        ResolvePath(scenarioPlan.EffectiveCleanupScriptFile, profileDirectory);

    // ============================================================
    // 9. SQL SERVER ENVIRONMENT INFO
    // ============================================================
    var sqlEnvironmentCollector = new SqlServerEnvironmentCollector(targetConnectionString);
    var sqlEnvironment = await sqlEnvironmentCollector.CollectAsync(cts.Token);

    // ============================================================
    // 10. HEADER
    // ============================================================
    Console.WriteLine("=== SQL STRESS LAB ===");
    Console.WriteLine($"Profile         : {fullProfilePath}");
    Console.WriteLine($"ProfileName     : {config.ProfileName}");
    Console.WriteLine($"ScenarioName    : {config.ScenarioName}");
    Console.WriteLine($"ScenarioType    : {scenarioPlan.Scenario.ScenarioType}");
    Console.WriteLine($"Environment     : {collectedEnvironment.EnvironmentName}");
    Console.WriteLine($"Server          : {config.Connection.Server}");
    Console.WriteLine($"Database        : {config.Connection.Database}");
    Console.WriteLine($"Authentication  : {config.Connection.Authentication}");
    Console.WriteLine($"Workers         : {options.Workers}");
    Console.WriteLine($"Iterations      : {options.IterationsPerWorker}");
    Console.WriteLine($"CommandType     : {options.CommandType}");
    Console.WriteLine($"ExecutionMode   : {options.ExecutionMode}");
    Console.WriteLine($"Session SET     : {options.SessionSettingsFile}");
    Console.WriteLine($"Output Dir      : {config.Output.Directory}");
    Console.WriteLine($"Markdown Dir    : {config.MarkdownReport.Directory}");
    Console.WriteLine($"Html Dir        : {config.HtmlReport.Directory}");
    Console.WriteLine($"Setup Script    : {scenarioPlan.EffectiveSetupScriptFile}");
    Console.WriteLine($"Cleanup Script  : {scenarioPlan.EffectiveCleanupScriptFile}");
    Console.WriteLine($"SQL Output      : {config.SqlOutput.Enabled}");
    Console.WriteLine($"Compare Enabled : {config.Compare.Enabled}");
    Console.WriteLine($"Compare Mode    : {config.Compare.Mode}");
    Console.WriteLine($"Trend Enabled   : {config.Trend.Enabled}");
    Console.WriteLine($"Trend Top N     : {config.Trend.Top}");
    Console.WriteLine($"SQL Version     : {sqlEnvironment.ProductVersion}");
    Console.WriteLine($"SQL Edition     : {sqlEnvironment.Edition}");
    Console.WriteLine($"Compat Level    : {sqlEnvironment.CompatibilityLevel}");
    Console.WriteLine();

    // ============================================================
    // 11. SETUP LIFECYCLE
    // ============================================================
    if (config.Lifecycle.SetupEnabled && !string.IsNullOrWhiteSpace(scenarioPlan.EffectiveSetupScriptFile))
    {
        Console.WriteLine("=== SETUP ===");
        Console.WriteLine($"Uruchamiam setup: {scenarioPlan.EffectiveSetupScriptFile}");

        try
        {
            await LifecycleScriptRunner.RunFileAsync(
                targetConnectionString,
                scenarioPlan.EffectiveSetupScriptFile,
                config.Execution.CommandTimeoutSeconds,
                cts.Token);

            Console.WriteLine("Setup zakończony powodzeniem.");
            Console.WriteLine();
        }
        catch (Exception ex)
        {
            Console.WriteLine("Błąd setup:");
            Console.WriteLine(ex.Message);
            Console.WriteLine();

            if (config.Lifecycle.StopRunWhenSetupFails)
            {
                return 20;
            }
        }
    }

    // ============================================================
    // 12. PRE-RUN DMV SNAPSHOT
    // ============================================================
    var dmvCollector = new DmvSnapshotCollector(targetConnectionString);
    var dmvSnapshots = new List<DmvSnapshot>();

    if (scenarioPlan.Scenario.RequiresDmvSnapshotBefore)
    {
        Console.WriteLine("=== DMV SNAPSHOT BEFORE ===");
        var beforeSnapshots = await dmvCollector.CollectAllAsync("PENDING", "Before", cts.Token);
        dmvSnapshots.AddRange(beforeSnapshots);
        Console.WriteLine($"Zebrano snapshotów before: {beforeSnapshots.Count}");
        Console.WriteLine();
    }

    // ============================================================
    // 13. LIVE PROGRESS
    // ============================================================
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

    // ============================================================
    // 14. RUN
    // ============================================================
    var runner = new StressRunner();

    var result = await runner.RunAsync(
        options,
        config.Retry,
        scenarioPlan.WorkerAssignments,
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

    // ============================================================
    // 15. POST-RUN DMV SNAPSHOT
    // ============================================================
    if (scenarioPlan.Scenario.RequiresDmvSnapshotAfter)
    {
        Console.WriteLine();
        Console.WriteLine("=== DMV SNAPSHOT AFTER ===");
        var afterSnapshots = await dmvCollector.CollectAllAsync(runId, "After", cts.Token);
        dmvSnapshots.AddRange(afterSnapshots);
        Console.WriteLine($"Zebrano snapshotów after: {afterSnapshots.Count}");
        Console.WriteLine();
    }

    foreach (var snap in dmvSnapshots.Where(x => x.RunId == "PENDING"))
    {
        snap.RunId = runId;
        foreach (var row in snap.Rows)
        {
            row.RunId = runId;
        }
    }

    // ============================================================
    // 16. CLEANUP LIFECYCLE
    // ============================================================
    if (config.Lifecycle.CleanupEnabled && !string.IsNullOrWhiteSpace(scenarioPlan.EffectiveCleanupScriptFile))
    {
        Console.WriteLine("=== CLEANUP ===");
        Console.WriteLine($"Uruchamiam cleanup: {scenarioPlan.EffectiveCleanupScriptFile}");

        try
        {
            await LifecycleScriptRunner.RunFileAsync(
                targetConnectionString,
                scenarioPlan.EffectiveCleanupScriptFile,
                config.Execution.CommandTimeoutSeconds,
                cts.Token);

            Console.WriteLine("Cleanup zakończony powodzeniem.");
        }
        catch (Exception ex)
        {
            Console.WriteLine("Błąd cleanup:");
            Console.WriteLine(ex.Message);

            if (!config.Lifecycle.ContinueWhenCleanupFails)
            {
                return 21;
            }
        }
    }

    // ============================================================
    // 17. BUILD RUN RECORD
    // ============================================================
    var runRecord = new StressRunRecord
    {
        RunId = runId,
        ProfileName = config.ProfileName,
        ScenarioName = config.ScenarioName,
        TagsCsv = string.Join(",", config.Tags.Tags),
        EnvironmentName = collectedEnvironment.EnvironmentName,
        MachineName = collectedEnvironment.MachineName,
        OsVersion = collectedEnvironment.OsVersion,
        DotNetVersion = collectedEnvironment.DotNetVersion,
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
        WallClockMs = (long)wallClock.TotalMilliseconds,
        SqlProductVersion = sqlEnvironment.ProductVersion,
        SqlProductLevel = sqlEnvironment.ProductLevel,
        SqlEdition = sqlEnvironment.Edition,
        SqlEngineEdition = sqlEnvironment.EngineEdition,
        SqlInstanceName = sqlEnvironment.InstanceName,
        SqlCompatibilityLevel = sqlEnvironment.CompatibilityLevel
    };

    var repository = config.SqlOutput.Enabled
        ? new SqlResultRepository(sqlOutputConnectionString)
        : null;

    // ============================================================
    // 18. OPTIONAL COMPARE
    // ============================================================
    RunComparisonResult? comparisonResult = null;

    if (config.Compare.Enabled && repository is not null)
    {
        Console.WriteLine("=== COMPARE ===");

        StressRunRecord? baselineRun = null;

        switch ((config.Compare.Mode ?? "None").Trim().ToLowerInvariant())
        {
            case "previousrun":
                baselineRun = await repository.GetLatestRunByProfileAsync(
                    config.ProfileName,
                    runId,
                    cts.Token);
                break;

            case "explicitrunid":
                if (!string.IsNullOrWhiteSpace(config.Compare.BaselineRunId))
                {
                    baselineRun = await repository.GetRunByIdAsync(
                        config.Compare.BaselineRunId,
                        cts.Token);
                }
                break;

            case "none":
            default:
                baselineRun = null;
                break;
        }

        if (baselineRun is null)
        {
            Console.WriteLine("Brak baseline do porównania.");
            Console.WriteLine();
        }
        else
        {
            comparisonResult = RunComparisonService.Compare(
                runRecord,
                baselineRun,
                config.Compare.IncludeSampleLevelDiff);

            Console.WriteLine($"Baseline RunId   : {baselineRun.RunId}");
            Console.WriteLine($"Delta AvgMs      : {comparisonResult.AvgDurationDeltaMs:F2}");
            Console.WriteLine($"Delta P95Ms      : {comparisonResult.P95DurationDeltaMs}");
            Console.WriteLine($"Delta Throughput : {comparisonResult.ThroughputDelta:F2}");
            Console.WriteLine($"Delta Errors     : {comparisonResult.ErrorCountDelta}");
            Console.WriteLine($"Regression       : {comparisonResult.IsRegression}");
            Console.WriteLine();
        }
    }

    // ============================================================
    // 19. OPTIONAL TREND
    // ============================================================
    TrendAnalysisResult? trendResult = null;

    if (config.Trend.Enabled && repository is not null)
    {
        Console.WriteLine("=== TREND ===");

        var trendRuns = await repository.GetLatestRunsByProfileAsync(
            config.ProfileName,
            config.Trend.Top,
            cts.Token);

        // Dodaj bieżący run do analizy trendu, jeśli jeszcze nie jest w repo
        var trendSourceRuns = new List<StressRunRecord> { runRecord };
        trendSourceRuns.AddRange(
            trendRuns.Where(x => !string.Equals(x.RunId, runRecord.RunId, StringComparison.OrdinalIgnoreCase)));

        var trendService = new TrendAnalysisService();
        trendResult = trendService.Analyze(
            config.ProfileName,
            trendSourceRuns,
            config.Trend.Top);

        Console.WriteLine($"Trend points     : {trendResult.Points.Count}");
        Console.WriteLine($"Avg direction    : {trendResult.AvgDurationTrendDirection}");
        Console.WriteLine($"P95 direction    : {trendResult.P95DurationTrendDirection}");
        Console.WriteLine($"Thr direction    : {trendResult.ThroughputTrendDirection}");
        Console.WriteLine($"Error direction  : {trendResult.ErrorTrendDirection}");
        Console.WriteLine($"Trend verdict    : {trendResult.SummaryVerdict}");
        Console.WriteLine();
    }

    // ============================================================
    // 20. CONSOLE SUMMARY
    // ============================================================
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

    // ============================================================
    // 21. WRITE FILE OUTPUTS
    // ============================================================
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

    if (comparisonResult is not null)
    {
        var comparisonJsonPath = Path.Combine(config.Output.Directory, $"comparison_{runId}.json");
        var comparisonJson = JsonSerializer.Serialize(comparisonResult, new JsonSerializerOptions
        {
            WriteIndented = true
        });

        await File.WriteAllTextAsync(comparisonJsonPath, comparisonJson, cts.Token);
        Console.WriteLine($"Comparison JSON zapisany do: {comparisonJsonPath}");
    }

    if (trendResult is not null)
    {
        var trendJsonPath = Path.Combine(config.Output.Directory, $"trend_{runId}.json");
        var trendJson = JsonSerializer.Serialize(trendResult, new JsonSerializerOptions
        {
            WriteIndented = true
        });

        await File.WriteAllTextAsync(trendJsonPath, trendJson, cts.Token);
        Console.WriteLine($"Trend JSON zapisany do: {trendJsonPath}");
    }

    // ============================================================
    // 22. WRITE MARKDOWN REPORT
    // ============================================================
    if (config.MarkdownReport.Enabled)
    {
        var markdownPath = Path.Combine(
            config.MarkdownReport.Directory,
            $"run_{runId}.md");

        await MarkdownReportWriter.WriteAsync(
            markdownPath,
            runRecord,
            samples,
            config.MarkdownReport,
            comparisonResult,
            trendResult,
            cts.Token);

        Console.WriteLine($"Markdown report zapisany do: {markdownPath}");
    }

    // ============================================================
    // 23. WRITE HTML REPORT
    // ============================================================
    if (config.HtmlReport.Enabled)
    {
        var htmlPath = Path.Combine(
            config.HtmlReport.Directory,
            $"run_{runId}.html");

        await HtmlReportWriter.WriteAsync(
            htmlPath,
            runRecord,
            sqlEnvironment,
            samples,
            dmvSnapshots,
            config.HtmlReport,
            comparisonResult,
            trendResult,
            cts.Token);

        Console.WriteLine($"HTML report zapisany do: {htmlPath}");
    }

    // ============================================================
    // 24. OPTIONAL SQL OUTPUT
    // ============================================================
    if (config.SqlOutput.Enabled && repository is not null)
    {
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
            ReaderRowCount = s.ReaderRowCount,
            Spid = s.Spid,
            HostName = s.HostName,
            AppName = s.AppName,
            LoginName = s.LoginName,
            DatabaseName = s.DatabaseName
        }).ToList();

        var bulkWriter = new BulkSampleWriter(sqlOutputConnectionString);
        await bulkWriter.WriteAsync(sampleRecords, cts.Token);

        var dmvRows = dmvSnapshots.SelectMany(x => x.Rows).ToList();
        await repository.InsertDmvSnapshotsAsync(dmvRows, cts.Token);

        if (comparisonResult is not null)
        {
            var comparisonRecord = new StressRunComparisonRecord
            {
                RunId = runId,
                BaselineRunId = comparisonResult.BaselineRunId,
                AvgDurationDeltaMs = comparisonResult.AvgDurationDeltaMs,
                P95DurationDeltaMs = comparisonResult.P95DurationDeltaMs,
                ThroughputDelta = comparisonResult.ThroughputDelta,
                ErrorCountDelta = comparisonResult.ErrorCountDelta,
                RetryCountDelta = comparisonResult.RetryCountDelta,
                IsRegression = comparisonResult.IsRegression,
                ComparedAtUtc = DateTime.UtcNow
            };

            await repository.InsertComparisonAsync(comparisonRecord, cts.Token);
        }

        Console.WriteLine("Wyniki, snapshoty DMV i comparison zapisane również do SQL Server.");
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