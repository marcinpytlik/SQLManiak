using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class TrendCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException(
                "Dla komendy 'trend' w tej wersji wymagany jest profil JSON, aby pobrać konfigurację repozytorium wyników.");

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

        if (!config.SqlOutput.Enabled)
            throw new InvalidOperationException("Komenda 'trend' wymaga 'sqlOutput.enabled = true'.");

        var repositoryConnectionString =
            config.SqlOutput.ConnectionMode?.Equals("Separate", StringComparison.OrdinalIgnoreCase) == true &&
            config.SqlOutput.Connection is not null
                ? ConnectionStringFactory.Build(config.SqlOutput.Connection)
                : ConnectionStringFactory.Build(config.Connection);

        var repository = new SqlResultRepository(repositoryConnectionString);

        var profileName = !string.IsNullOrWhiteSpace(args.ProfileName)
            ? args.ProfileName
            : config.ProfileName;

        var top = args.Top > 0 ? args.Top : config.Trend.Top;
        if (top <= 0)
            top = 10;

        var runs = await repository.GetLatestRunsByProfileAsync(profileName, top, cancellationToken);

        if (runs.Count == 0)
            throw new InvalidOperationException($"Brak runów dla profilu '{profileName}'.");

        var trendService = new TrendAnalysisService();
        var trendResult = trendService.Analyze(profileName, runs, top);

        Console.WriteLine("=== SQL STRESS LAB / TREND ===");
        Console.WriteLine($"ProfileName      : {trendResult.ProfileName}");
        Console.WriteLine($"RequestedTop     : {trendResult.RequestedTop}");
        Console.WriteLine($"Points           : {trendResult.Points.Count}");
        Console.WriteLine($"AvgDirection     : {trendResult.AvgDurationTrendDirection}");
        Console.WriteLine($"P95Direction     : {trendResult.P95DurationTrendDirection}");
        Console.WriteLine($"ThrDirection     : {trendResult.ThroughputTrendDirection}");
        Console.WriteLine($"ErrDirection     : {trendResult.ErrorTrendDirection}");
        Console.WriteLine($"SummaryVerdict   : {trendResult.SummaryVerdict}");
        Console.WriteLine();

        var trendJsonPath = Path.Combine(
            config.Output.Directory,
            $"trend_only_{profileName}_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json");

        var trendJson = JsonSerializer.Serialize(trendResult, new JsonSerializerOptions
        {
            WriteIndented = true
        });

        await File.WriteAllTextAsync(trendJsonPath, trendJson, cancellationToken);
        Console.WriteLine($"Trend JSON zapisany do: {trendJsonPath}");

        if (config.MarkdownReport.Enabled)
        {
            var newestRun = runs
                .OrderByDescending(x => x.StartedAtUtc)
                .First();

            var markdownPath = Path.Combine(
                config.MarkdownReport.Directory,
                $"trend_{profileName}_{DateTime.UtcNow:yyyyMMdd_HHmmss}.md");

            await MarkdownReportWriter.WriteAsync(
                markdownPath,
                newestRun,
                new List<ExecutionSample>(),
                config.MarkdownReport,
                null,
                trendResult,
                cancellationToken);

            Console.WriteLine($"Markdown report zapisany do: {markdownPath}");
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