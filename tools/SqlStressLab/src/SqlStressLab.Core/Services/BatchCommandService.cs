using System.Text.Json;
using SqlStressLab.Core.CLI;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class BatchCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException("Dla komendy 'batch' wymagany jest profil JSON.");

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

        if (!config.Batch.Enabled)
            throw new InvalidOperationException("Sekcja Batch jest wyłączona.");

        if (config.Batch.ProfileFiles.Count == 0)
            throw new InvalidOperationException("Batch nie zawiera żadnych ProfileFiles.");

        Console.WriteLine("=== SQL STRESS LAB / BATCH ===");
        Console.WriteLine($"Profiles : {config.Batch.ProfileFiles.Count}");
        Console.WriteLine($"StopOnError : {config.Batch.StopOnError}");
        Console.WriteLine();

        var runService = new RunCommandService();
        var success = 0;
        var failed = 0;
        var index = 0;

        foreach (var profile in config.Batch.ProfileFiles)
        {
            cancellationToken.ThrowIfCancellationRequested();
            index++;

            var fullProfile = Path.IsPathRooted(profile)
                ? profile
                : Path.GetFullPath(Path.Combine(rootDirectory, profile));

            Console.WriteLine($"[{index}/{config.Batch.ProfileFiles.Count}] {fullProfile}");

            var runArgs = new CliArguments
            {
                Command = CommandNames.Run,
                ProfilePath = fullProfile,
                DisableReports = args.DisableReports,
                DisableSqlOutput = args.DisableSqlOutput,
                OutputDirectoryOverride = args.OutputDirectoryOverride
            };

            var exitCode = await runService.ExecuteAsync(runArgs, cancellationToken);

            if (exitCode == 0)
            {
                success++;
            }
            else
            {
                failed++;
                if (config.Batch.StopOnError)
                {
                    Console.WriteLine("Batch przerwany po błędzie.");
                    Console.WriteLine($"Succeeded: {success}, Failed: {failed}");
                    return 1;
                }
            }

            Console.WriteLine();
        }

        Console.WriteLine("=== BATCH SUMMARY ===");
        Console.WriteLine($"Succeeded : {success}");
        Console.WriteLine($"Failed    : {failed}");

        return failed == 0 ? 0 : 1;
    }
}