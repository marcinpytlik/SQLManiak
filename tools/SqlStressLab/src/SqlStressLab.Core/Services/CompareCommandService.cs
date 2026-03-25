using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class CompareCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException(
                "Dla komendy 'compare' wymagany jest profil JSON, aby pobrać konfigurację repozytorium wyników.");

        var fullProfilePath = Path.GetFullPath(args.ProfilePath);

        if (!File.Exists(fullProfilePath))
            throw new FileNotFoundException($"Brak pliku profilu: {fullProfilePath}");

        var profileDirectory = Path.GetDirectoryName(fullProfilePath)
                               ?? Directory.GetCurrentDirectory();

        var json = await File.ReadAllTextAsync(fullProfilePath, cancellationToken);

        var config = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (config is null)
            throw new InvalidOperationException("Nie udało się zdeserializować konfiguracji.");

        ResolvePasswordFromEnvironment(config.Connection);

        if (config.SqlOutput.Connection is not null)
        {
            ResolvePasswordFromEnvironment(config.SqlOutput.Connection);
        }

        config.Output.Directory =
            ResolvePath(config.Output.Directory, profileDirectory) ?? Path.Combine(profileDirectory, "outputs");

        config.MarkdownReport.Directory =
            ResolvePath(config.MarkdownReport.Directory, profileDirectory) ?? config.Output.Directory;

        config.HtmlReport.Directory =
            ResolvePath(config.HtmlReport.Directory, profileDirectory) ?? config.Output.Directory;

        if (!string.IsNullOrWhiteSpace(args.OutputDirectoryOverride))
        {
            var overrideDir = ResolvePath(args.OutputDirectoryOverride, Directory.GetCurrentDirectory())
                              ?? args.OutputDirectoryOverride;

            config.Output.Directory = overrideDir;
            config.MarkdownReport.Directory = overrideDir;
            config.HtmlReport.Directory = overrideDir;
        }

        if (args.DisableReports)
        {
            config.Output.WriteJson = false;
            config.Output.WriteCsv = false;
            config.Output.WriteReaderPreview = false;
            config.MarkdownReport.Enabled = false;
            config.HtmlReport.Enabled = false;
        }

        if (!config.SqlOutput.Enabled)
            throw new InvalidOperationException("Komenda 'compare' wymaga 'sqlOutput.enabled = true'.");

        var repositoryConnectionString =
            config.SqlOutput.ConnectionMode?.Equals("Separate", StringComparison.OrdinalIgnoreCase) == true &&
            config.SqlOutput.Connection is not null
                ? ConnectionStringFactory.Build(config.SqlOutput.Connection)
                : ConnectionStringFactory.Build(config.Connection);

        var repository = new SqlResultRepository(repositoryConnectionString);

        var profileName = !string.IsNullOrWhiteSpace(args.ProfileName)
            ? args.ProfileName
            : config.ProfileName;

        StressRunRecord? currentRun = null;
        StressRunRecord? baselineRun = null;

        if (!string.IsNullOrWhiteSpace(args.CurrentRunId))
        {
            currentRun = await repository.GetRunByIdAsync(args.CurrentRunId, cancellationToken);
            if (currentRun is null)
                throw new InvalidOperationException($"Nie znaleziono current run: {args.CurrentRunId}");
        }
        else
        {
            var latestRuns = await repository.GetLatestRunsByProfileAsync(profileName, 1, cancellationToken);
            currentRun = latestRuns.FirstOrDefault();

            if (currentRun is null)
                throw new InvalidOperationException($"Brak runów dla profilu '{profileName}'.");
        }

        if (!string.IsNullOrWhiteSpace(args.BaselineRunId))
        {
            baselineRun = await repository.GetRunByIdAsync(args.BaselineRunId, cancellationToken);
            if (baselineRun is null)
                throw new InvalidOperationException($"Nie znaleziono baseline run: {args.BaselineRunId}");
        }
        else
        {
            switch ((config.Compare.Mode ?? "PreviousRun").Trim().ToLowerInvariant())
            {
                case "explicitrunid":
                    if (string.IsNullOrWhiteSpace(config.Compare.BaselineRunId))
                        throw new InvalidOperationException("Compare mode = ExplicitRunId, ale brak compare.baselineRunId.");

                    baselineRun = await repository.GetRunByIdAsync(config.Compare.BaselineRunId, cancellationToken);
                    break;

                case "previousrun":
                default:
                    baselineRun = await repository.GetLatestRunByProfileAsync(
                        profileName,
                        currentRun.RunId,
                        cancellationToken);
                    break;
            }
        }

        if (baselineRun is null)
            throw new InvalidOperationException("Nie udało się wyznaczyć baseline run.");

        var comparisonResult = RunComparisonService.Compare(
            currentRun,
            baselineRun,
            args.IncludeSampleLevelDiff || config.Compare.IncludeSampleLevelDiff);

        Console.WriteLine("=== SQL STRESS LAB / COMPARE ===");
        Console.WriteLine($"ProfileName      : {profileName}");
        Console.WriteLine($"CurrentRunId     : {currentRun.RunId}");
        Console.WriteLine($"BaselineRunId    : {baselineRun.RunId}");
        Console.WriteLine($"AvgDurationDelta : {comparisonResult.AvgDurationDeltaMs:F2}");
        Console.WriteLine($"P95DurationDelta : {comparisonResult.P95DurationDeltaMs}");
        Console.WriteLine($"ThroughputDelta  : {comparisonResult.ThroughputDelta:F2}");
        Console.WriteLine($"ErrorCountDelta  : {comparisonResult.ErrorCountDelta}");
        Console.WriteLine($"RetryCountDelta  : {comparisonResult.RetryCountDelta}");
        Console.WriteLine($"IsRegression     : {comparisonResult.IsRegression}");
        Console.WriteLine();

        if (config.Output.WriteJson)
        {
            var compareJsonPath = Path.Combine(
                config.Output.Directory,
                $"compare_only_{currentRun.RunId}_vs_{baselineRun.RunId}.json");

            var compareJson = JsonSerializer.Serialize(comparisonResult, new JsonSerializerOptions
            {
                WriteIndented = true
            });

            await File.WriteAllTextAsync(compareJsonPath, compareJson, cancellationToken);
            Console.WriteLine($"Comparison JSON zapisany do: {compareJsonPath}");
        }

        if (config.MarkdownReport.Enabled)
        {
            var markdownPath = Path.Combine(
                config.MarkdownReport.Directory,
                $"compare_{currentRun.RunId}_vs_{baselineRun.RunId}.md");

            await MarkdownReportWriter.WriteAsync(
                markdownPath,
                currentRun,
                new List<ExecutionSample>(),
                config.MarkdownReport,
                comparisonResult,
                null,
                cancellationToken);

            Console.WriteLine($"Markdown report zapisany do: {markdownPath}");
        }

        if (config.SqlOutput.Enabled)
        {
            var comparisonRecord = new StressRunComparisonRecord
            {
                RunId = currentRun.RunId,
                BaselineRunId = baselineRun.RunId,
                AvgDurationDeltaMs = comparisonResult.AvgDurationDeltaMs,
                P95DurationDeltaMs = comparisonResult.P95DurationDeltaMs,
                ThroughputDelta = comparisonResult.ThroughputDelta,
                ErrorCountDelta = comparisonResult.ErrorCountDelta,
                RetryCountDelta = comparisonResult.RetryCountDelta,
                IsRegression = comparisonResult.IsRegression,
                ComparedAtUtc = DateTime.UtcNow
            };

            await repository.InsertComparisonAsync(comparisonRecord, cancellationToken);
            Console.WriteLine("Comparison zapisany również do SQL Server.");
        }

        return 0;
    }

    private static void ResolvePasswordFromEnvironment(SqlAuthOptions connection)
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

    private static string? ResolvePath(string? path, string baseDirectory)
    {
        if (string.IsNullOrWhiteSpace(path))
            return path;

        if (Path.IsPathRooted(path))
            return path;

        return Path.GetFullPath(Path.Combine(baseDirectory, path));
    }
}