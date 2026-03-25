using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class ListRunsCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException(
                "Dla komendy 'list-runs' wymagany jest profil JSON, aby pobrać konfigurację repozytorium wyników.");

        var fullProfilePath = Path.GetFullPath(args.ProfilePath);

        if (!File.Exists(fullProfilePath))
            throw new FileNotFoundException($"Brak pliku profilu: {fullProfilePath}");

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

        if (!config.SqlOutput.Enabled)
            throw new InvalidOperationException("Komenda 'list-runs' wymaga 'sqlOutput.enabled = true'.");

        var repositoryConnectionString =
            config.SqlOutput.ConnectionMode?.Equals("Separate", StringComparison.OrdinalIgnoreCase) == true &&
            config.SqlOutput.Connection is not null
                ? ConnectionStringFactory.Build(config.SqlOutput.Connection)
                : ConnectionStringFactory.Build(config.Connection);

        var repository = new SqlResultRepository(repositoryConnectionString);

        var profileName = !string.IsNullOrWhiteSpace(args.ProfileName)
            ? args.ProfileName
            : config.ProfileName;

        var top = args.Top > 0 ? args.Top : 20;

        var runs = await repository.GetLatestRunsByProfileAsync(profileName, top, cancellationToken);

        Console.WriteLine("=== SQL STRESS LAB / LIST-RUNS ===");
        Console.WriteLine($"ProfileName : {profileName}");
        Console.WriteLine($"Top         : {top}");
        Console.WriteLine();

        if (runs.Count == 0)
        {
            Console.WriteLine("Brak runów.");
            return 0;
        }

        Console.WriteLine(
            $"{Pad("RunId", 24)} " +
            $"{Pad("StartedAtUtc", 20)} " +
            $"{Pad("AvgMs", 10)} " +
            $"{Pad("P95", 8)} " +
            $"{Pad("Thr/s", 10)} " +
            $"{Pad("Errors", 8)} " +
            $"{Pad("Retries", 8)}");

        Console.WriteLine(new string('-', 96));

        foreach (var run in runs.OrderByDescending(x => x.StartedAtUtc))
        {
            Console.WriteLine(
                $"{Pad(run.RunId, 24)} " +
                $"{Pad(run.StartedAtUtc.ToString("yyyy-MM-dd HH:mm:ss"), 20)} " +
                $"{Pad(run.AvgDurationMs.ToString("F2"), 10)} " +
                $"{Pad(run.P95DurationMs.ToString(), 8)} " +
                $"{Pad(run.ThroughputPerSecond.ToString("F2"), 10)} " +
                $"{Pad(run.ErrorCount.ToString(), 8)} " +
                $"{Pad(run.RetryCount.ToString(), 8)}");
        }

        return 0;
    }

    private static string Pad(string? value, int width)
        => (value ?? string.Empty).PadRight(width);

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
}