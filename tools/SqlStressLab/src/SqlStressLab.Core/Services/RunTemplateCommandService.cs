using System.Text.Json;
using SqlStressLab.Core.Models;
using SqlStressLab.Core.CLI;

namespace SqlStressLab.Core.Services;

public sealed class RunTemplateCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException("Dla komendy 'run-template' wymagany jest profil JSON.");

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

        var tempDirectory = Path.Combine(
            Path.GetDirectoryName(fullProfilePath) ?? Directory.GetCurrentDirectory(),
            "outputs",
            "rendered");

        Directory.CreateDirectory(tempDirectory);

        var tempProfilePath = Path.Combine(
            tempDirectory,
            $"template_run_{Sanitize(template.Name)}_{DateTime.UtcNow:yyyyMMdd_HHmmss}.json");

        await File.WriteAllTextAsync(tempProfilePath, renderedJson, cancellationToken);

        Console.WriteLine("=== SQL STRESS LAB / RUN-TEMPLATE ===");
        Console.WriteLine($"Template      : {template.Name}");
        Console.WriteLine($"Rendered file : {tempProfilePath}");
        Console.WriteLine();

        var runArgs = new CliArguments
        {
            Command = CommandNames.Run,
            ProfilePath = tempProfilePath,
            DisableReports = args.DisableReports,
            DisableSqlOutput = args.DisableSqlOutput,
            OutputDirectoryOverride = args.OutputDirectoryOverride
        };

        var runService = new RunCommandService();
        return await runService.ExecuteAsync(runArgs, cancellationToken);
    }

    private static string Sanitize(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return new string(value.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray());
    }
}