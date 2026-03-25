using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class BundleCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException("Dla komendy 'bundle' wymagany jest profil JSON.");

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

        if (!config.Bundle.Enabled)
            throw new InvalidOperationException("Sekcja Bundle jest wyłączona.");

        if (string.IsNullOrWhiteSpace(config.Bundle.OutputFile))
            throw new InvalidOperationException("Bundle.OutputFile jest wymagany.");

        var files = new List<string>();

        foreach (var item in config.Bundle.IncludeFiles)
        {
            var fullPath = Path.IsPathRooted(item)
                ? item
                : Path.GetFullPath(Path.Combine(rootDirectory, item));

            if (File.Exists(fullPath))
            {
                files.Add(fullPath);
            }
        }

        if (files.Count == 0)
            throw new InvalidOperationException("Bundle nie zawiera żadnych istniejących plików.");

        var outputZip = Path.IsPathRooted(config.Bundle.OutputFile)
            ? config.Bundle.OutputFile
            : Path.GetFullPath(Path.Combine(rootDirectory, config.Bundle.OutputFile));

        ZipBundleWriter.CreateBundle(outputZip, files);

        Console.WriteLine("=== SQL STRESS LAB / BUNDLE ===");
        Console.WriteLine($"OutputFile : {outputZip}");
        Console.WriteLine($"Files      : {files.Count}");

        return 0;
    }
}