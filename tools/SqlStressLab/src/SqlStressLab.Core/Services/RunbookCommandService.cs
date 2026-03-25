using System.Text.Json;
using SqlStressLab.Core.CLI;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class RunbookCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException("Dla komendy 'runbook' wymagany jest profil JSON.");

        var rootProfilePath = Path.GetFullPath(args.ProfilePath);
        if (!File.Exists(rootProfilePath))
            throw new FileNotFoundException($"Brak pliku profilu: {rootProfilePath}");

        var rootDirectory = Path.GetDirectoryName(rootProfilePath) ?? Directory.GetCurrentDirectory();

        var json = await File.ReadAllTextAsync(rootProfilePath, cancellationToken);
        var config = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (config is null)
            throw new InvalidOperationException("Nie udało się zdeserializować root config.");

        if (!config.Runbook.Enabled)
            throw new InvalidOperationException("Sekcja Runbook jest wyłączona.");

        if (config.Runbook.Steps.Count == 0)
            throw new InvalidOperationException("Runbook nie zawiera żadnych kroków.");

        Console.WriteLine("=== SQL STRESS LAB / RUNBOOK ===");
        Console.WriteLine($"Steps : {config.Runbook.Steps.Count}");
        Console.WriteLine();

        var success = 0;
        var failed = 0;

        foreach (var step in config.Runbook.Steps)
        {
            cancellationToken.ThrowIfCancellationRequested();

            Console.WriteLine($"Step: {step.Name}");
            Console.WriteLine($"Command: {step.Command}");

            var stepProfile = Path.IsPathRooted(step.ProfilePath)
                ? step.ProfilePath
                : Path.GetFullPath(Path.Combine(rootDirectory, step.ProfilePath));

            var stepArgs = new CliArguments
            {
                Command = step.Command,
                ProfilePath = stepProfile,
                DisableReports = args.DisableReports,
                DisableSqlOutput = args.DisableSqlOutput,
                OutputDirectoryOverride = args.OutputDirectoryOverride
            };

            var exitCode = await ExecuteStepAsync(stepArgs, cancellationToken);

            if (exitCode == 0)
            {
                success++;
            }
            else
            {
                failed++;
                if (!step.ContinueOnError)
                {
                    Console.WriteLine("Runbook przerwany po błędzie.");
                    Console.WriteLine($"Succeeded: {success}, Failed: {failed}");
                    return 1;
                }
            }

            Console.WriteLine();
        }

        Console.WriteLine("=== RUNBOOK SUMMARY ===");
        Console.WriteLine($"Succeeded : {success}");
        Console.WriteLine($"Failed    : {failed}");

        return failed == 0 ? 0 : 1;
    }

    private static async Task<int> ExecuteStepAsync(CliArguments args, CancellationToken cancellationToken)
    {
        return (args.Command ?? CommandNames.Run).ToLowerInvariant() switch
        {
            CommandNames.Run => await new RunCommandService().ExecuteAsync(args, cancellationToken),
            CommandNames.Compare => await new CompareCommandService().ExecuteAsync(args, cancellationToken),
            CommandNames.Trend => await new TrendCommandService().ExecuteAsync(args, cancellationToken),
            CommandNames.Diagnostics => await new DiagnosticsCommandService().ExecuteAsync(args, cancellationToken),
            CommandNames.SelfCheck => await new SelfCheckCommandService().ExecuteAsync(args, cancellationToken),
            _ => throw new InvalidOperationException($"Runbook step command '{args.Command}' nie jest obsługiwana.")
        };
    }
}