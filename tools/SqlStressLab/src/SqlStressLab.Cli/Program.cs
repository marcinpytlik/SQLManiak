using System.Text.Json;
using SqlStressLab.Core.Models;
using SqlStressLab.Core.Services;

Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
};

var cts = new CancellationTokenSource();

try
{
    var profilePath = args.Length > 0 ? args[0] : "profiles/demo-select.json";

    if (!File.Exists(profilePath))
    {
        Console.WriteLine($"Brak pliku profilu: {profilePath}");
        return 1;
    }

    var json = await File.ReadAllTextAsync(profilePath, cts.Token);
    var config = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true
    });

    if (config is null)
    {
        Console.WriteLine("Nie udało się zdeserializować konfiguracji.");
        return 2;
    }

    ResolvePasswordFromEnvironment(config.Connection);

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

    Console.WriteLine("=== SQL STRESS LAB ===");
    Console.WriteLine($"Server         : {config.Connection.Server}");
    Console.WriteLine($"Database       : {config.Connection.Database}");
    Console.WriteLine($"Authentication : {config.Connection.Authentication}");
    Console.WriteLine($"Workers        : {options.Workers}");
    Console.WriteLine($"Iterations     : {options.IterationsPerWorker}");
    Console.WriteLine($"CommandType    : {options.CommandType}");
    Console.WriteLine($"ExecutionMode  : {options.ExecutionMode}");
    Console.WriteLine($"Session SET    : {options.SessionSettingsFile}");
    Console.WriteLine();

    var runner = new StressRunner();
    var startedAt = DateTime.UtcNow;

    var (summary, samples) = await runner.RunAsync(options, cts.Token);

    var finishedAt = DateTime.UtcNow;
    var duration = finishedAt - startedAt;

    Console.WriteLine("=== PODSUMOWANIE ===");
    Console.WriteLine($"TotalExecutions : {summary.TotalExecutions}");
    Console.WriteLine($"SuccessCount    : {summary.SuccessCount}");
    Console.WriteLine($"ErrorCount      : {summary.ErrorCount}");
    Console.WriteLine($"AvgDurationMs   : {summary.AvgDurationMs:F2}");
    Console.WriteLine($"MinDurationMs   : {summary.MinDurationMs}");
    Console.WriteLine($"P50DurationMs   : {summary.P50DurationMs}");
    Console.WriteLine($"P95DurationMs   : {summary.P95DurationMs}");
    Console.WriteLine($"P99DurationMs   : {summary.P99DurationMs}");
    Console.WriteLine($"MaxDurationMs   : {summary.MaxDurationMs}");
    Console.WriteLine($"Throughput/s    : {summary.ThroughputPerSecond:F2}");
    Console.WriteLine($"WallClock       : {duration}");
    Console.WriteLine();

    var errors = samples
        .Where(x => !x.Success)
        .GroupBy(x => x.ErrorCategory)
        .Select(g => new { Category = g.Key, Count = g.Count() })
        .OrderByDescending(x => x.Count)
        .ToList();

    if (errors.Count > 0)
    {
        Console.WriteLine("=== BŁĘDY ===");
        foreach (var err in errors)
        {
            Console.WriteLine($"{err.Category}: {err.Count}");
        }
        Console.WriteLine();
    }

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