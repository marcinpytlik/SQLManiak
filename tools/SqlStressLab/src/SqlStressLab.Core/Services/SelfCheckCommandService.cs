using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class SelfCheckCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException(
                "Dla komendy 'self-check' wymagany jest profil JSON.");

        var fullProfilePath = Path.GetFullPath(args.ProfilePath);

        if (!File.Exists(fullProfilePath))
            throw new FileNotFoundException($"Brak pliku profilu: {fullProfilePath}");

        var profileDirectory = Path.GetDirectoryName(fullProfilePath)
                               ?? Directory.GetCurrentDirectory();

        var messages = new List<string>();
        var success = true;

        var json = await File.ReadAllTextAsync(fullProfilePath, cancellationToken);

        var config = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (config is null)
            throw new InvalidOperationException("Nie udało się zdeserializować konfiguracji.");

        messages.Add($"Profile file OK: {fullProfilePath}");
        messages.Add($"ProfileName: {config.ProfileName}");
        messages.Add($"ScenarioName: {config.ScenarioName}");

        if (string.IsNullOrWhiteSpace(config.Connection.Server))
        {
            success = false;
            messages.Add("Connection.Server MISSING");
        }
        else
        {
            messages.Add($"Connection.Server OK: {config.Connection.Server}");
        }

        if (string.IsNullOrWhiteSpace(config.Connection.Database))
        {
            success = false;
            messages.Add("Connection.Database MISSING");
        }
        else
        {
            messages.Add($"Connection.Database OK: {config.Connection.Database}");
        }

        if (config.Execution.Workers <= 0)
        {
            success = false;
            messages.Add("Execution.Workers INVALID");
        }
        else
        {
            messages.Add($"Execution.Workers OK: {config.Execution.Workers}");
        }

        if (config.Execution.IterationsPerWorker <= 0)
        {
            success = false;
            messages.Add("Execution.IterationsPerWorker INVALID");
        }
        else
        {
            messages.Add($"Execution.IterationsPerWorker OK: {config.Execution.IterationsPerWorker}");
        }

        var sessionSettingsPath = ResolvePath(config.Execution.SessionSettingsFile, profileDirectory);
        if (!string.IsNullOrWhiteSpace(sessionSettingsPath))
        {
            if (File.Exists(sessionSettingsPath))
                messages.Add($"Session settings OK: {sessionSettingsPath}");
            else
            {
                success = false;
                messages.Add($"Session settings MISSING: {sessionSettingsPath}");
            }
        }

        var outputDirectory = !string.IsNullOrWhiteSpace(args.OutputDirectoryOverride)
            ? ResolvePath(args.OutputDirectoryOverride, Directory.GetCurrentDirectory())
            : ResolvePath(config.Output.Directory, profileDirectory);

        if (string.IsNullOrWhiteSpace(outputDirectory))
        {
            outputDirectory = Path.Combine(profileDirectory, "outputs");
        }

        try
        {
            Directory.CreateDirectory(outputDirectory);
            messages.Add($"Output directory OK: {outputDirectory}");
        }
        catch (Exception ex)
        {
            success = false;
            messages.Add($"Output directory FAILED: {outputDirectory} ({ex.Message})");
        }

        if (string.Equals(config.Connection.Authentication, "SqlPassword", StringComparison.OrdinalIgnoreCase))
        {
            var hasPassword =
                !string.IsNullOrWhiteSpace(config.Connection.Password) ||
                !string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("SQLSTRESSLAB_PASSWORD"));

            if (hasPassword)
                messages.Add("SQL password source OK");
            else
            {
                success = false;
                messages.Add("SQL password source MISSING");
            }
        }

        Console.WriteLine("=== SQL STRESS LAB / SELF-CHECK ===");
        foreach (var message in messages)
        {
            Console.WriteLine(message);
        }

        Console.WriteLine();
        Console.WriteLine(success
            ? "Self-check: SUCCESS"
            : "Self-check: FAILED");

        return success ? 0 : 1;
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