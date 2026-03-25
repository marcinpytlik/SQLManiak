using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class RenderCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException("Dla komendy 'render' wymagany jest profil JSON.");

        var fullProfilePath = Path.GetFullPath(args.ProfilePath);

        if (!File.Exists(fullProfilePath))
            throw new FileNotFoundException($"Brak pliku profilu: {fullProfilePath}");

        var json = await File.ReadAllTextAsync(fullProfilePath, cancellationToken);

        var rootConfig = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (rootConfig is null)
            throw new InvalidOperationException("Nie udało się zdeserializować root config.");

        if (rootConfig.Templates.Count == 0)
            throw new InvalidOperationException("Brak sekcji Templates w pliku root.");

        var template = rootConfig.Templates.First();

        var resolver = new TemplateResolver();
        var renderedJson = await resolver.RenderTemplateAsync(fullProfilePath, template, cancellationToken);

        var outputDirectory = string.IsNullOrWhiteSpace(args.OutputDirectoryOverride)
            ? Path.Combine(Path.GetDirectoryName(fullProfilePath) ?? Directory.GetCurrentDirectory(), "outputs")
            : Path.GetFullPath(args.OutputDirectoryOverride);

        Directory.CreateDirectory(outputDirectory);

        var outputPath = Path.Combine(
            outputDirectory,
            $"render_{Sanitize(template.Name)}_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json");

        await File.WriteAllTextAsync(outputPath, renderedJson, cancellationToken);

        Console.WriteLine("=== SQL STRESS LAB / RENDER ===");
        Console.WriteLine($"Template   : {template.Name}");
        Console.WriteLine($"OutputFile : {outputPath}");

        return 0;
    }

    private static string Sanitize(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return new string(value.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray());
    }
}