using System.Text.Json;
using Microsoft.Data.SqlClient;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class DiagnosticsCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException(
                "Dla komendy 'diagnostics' wymagany jest profil JSON.");

        var fullProfilePath = Path.GetFullPath(args.ProfilePath);

        if (!File.Exists(fullProfilePath))
            throw new FileNotFoundException($"Brak pliku profilu: {fullProfilePath}");

        var profileDirectory = Path.GetDirectoryName(fullProfilePath)
                               ?? Directory.GetCurrentDirectory();

        var result = new DiagnosticsResult { Success = true };

        try
        {
            var json = await File.ReadAllTextAsync(fullProfilePath, cancellationToken);

            var config = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (config is null)
                throw new InvalidOperationException("Nie udało się zdeserializować konfiguracji.");

            ResolvePasswordFromEnvironment(config.Connection);

            var sessionSettingsPath = ResolvePath(config.Execution.SessionSettingsFile, profileDirectory);

            result.Messages.Add($"Profile file OK: {fullProfilePath}");
            result.Messages.Add($"ProfileName: {config.ProfileName}");
            result.Messages.Add($"ScenarioName: {config.ScenarioName}");
            result.Messages.Add($"Server: {config.Connection.Server}");
            result.Messages.Add($"Database: {config.Connection.Database}");
            result.Messages.Add($"Authentication: {config.Connection.Authentication}");

            if (!string.IsNullOrWhiteSpace(sessionSettingsPath))
            {
                if (File.Exists(sessionSettingsPath))
                    result.Messages.Add($"Session settings OK: {sessionSettingsPath}");
                else
                {
                    result.Success = false;
                    result.Messages.Add($"Session settings MISSING: {sessionSettingsPath}");
                }
            }

            var connectionString = ConnectionStringFactory.Build(config.Connection);

            await using var connection = new SqlConnection(connectionString);
            await connection.OpenAsync(cancellationToken);

            result.Messages.Add("SQL connection OK");

            var collector = new SqlServerEnvironmentCollector(connectionString);
            var sqlEnvironment = await collector.CollectAsync(cancellationToken);

            result.Messages.Add($"SQL Version: {sqlEnvironment.ProductVersion}");
            result.Messages.Add($"SQL Edition: {sqlEnvironment.Edition}");
            result.Messages.Add($"SQL CompatibilityLevel: {sqlEnvironment.CompatibilityLevel}");

            if (config.SqlOutput.Enabled)
            {
                SqlAuthOptions outputConnection =
                    config.SqlOutput.ConnectionMode?.Equals("Separate", StringComparison.OrdinalIgnoreCase) == true &&
                    config.SqlOutput.Connection is not null
                        ? config.SqlOutput.Connection
                        : config.Connection;

                ResolvePasswordFromEnvironment(outputConnection);

                var outputConnectionString = ConnectionStringFactory.Build(outputConnection);
                await using var outputSqlConnection = new SqlConnection(outputConnectionString);
                await outputSqlConnection.OpenAsync(cancellationToken);

                result.Messages.Add("SQL output connection OK");
            }
        }
        catch (Exception ex)
        {
            result.Success = false;
            result.Messages.Add($"ERROR: {ex.Message}");
        }

        Console.WriteLine("=== SQL STRESS LAB / DIAGNOSTICS ===");
        foreach (var message in result.Messages)
        {
            Console.WriteLine(message);
        }

        Console.WriteLine();
        Console.WriteLine(result.Success
            ? "Diagnostics: SUCCESS"
            : "Diagnostics: FAILED");

        return result.Success ? 0 : 1;
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