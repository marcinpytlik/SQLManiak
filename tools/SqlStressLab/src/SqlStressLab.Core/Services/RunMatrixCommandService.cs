using System.Text.Json;
using SqlStressLab.Core.CLI;
using SqlStressLab.Core.Models;
using SqlStressLab.Core.Templates;

namespace SqlStressLab.Core.Services;

public sealed class RunMatrixCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException("Dla komendy 'run-matrix' wymagany jest profil JSON.");

        var fullProfilePath = Path.GetFullPath(args.ProfilePath);

        if (!File.Exists(fullProfilePath))
            throw new FileNotFoundException($"Brak pliku profilu: {fullProfilePath}");

        var rootDirectory = Path.GetDirectoryName(fullProfilePath) ?? Directory.GetCurrentDirectory();

        var json = await File.ReadAllTextAsync(fullProfilePath, cancellationToken);

        var rootConfig = JsonSerializer.Deserialize<RootConfig>(json, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (rootConfig is null)
            throw new InvalidOperationException("Nie udało się zdeserializować root config.");

        if (rootConfig.Matrices.Count == 0)
            throw new InvalidOperationException("Brak sekcji Matrices w pliku root.");

        var matrix = rootConfig.Matrices.First();

        if (string.IsNullOrWhiteSpace(matrix.BaseProfilePath))
            throw new InvalidOperationException($"Matrix '{matrix.Name}' nie ma BaseProfilePath.");

        var baseProfilePath = matrix.BaseProfilePath;
        if (!Path.IsPathRooted(baseProfilePath))
            baseProfilePath = Path.GetFullPath(Path.Combine(rootDirectory, baseProfilePath));

        if (!File.Exists(baseProfilePath))
            throw new FileNotFoundException($"Brak base profile dla matrix: {baseProfilePath}");

        var baseJson = await File.ReadAllTextAsync(baseProfilePath, cancellationToken);

        var expander = new MatrixExpander();
        var variants = expander.Expand(matrix);

        if (variants.Count == 0)
            throw new InvalidOperationException("Matrix nie wygenerował żadnych wariantów.");

        var renderedDirectory = Path.Combine(rootDirectory, "outputs", "matrix");
        Directory.CreateDirectory(renderedDirectory);

        Console.WriteLine("=== SQL STRESS LAB / RUN-MATRIX ===");
        Console.WriteLine($"Matrix         : {matrix.Name}");
        Console.WriteLine($"Variant count  : {variants.Count}");
        Console.WriteLine();

        var runService = new RunCommandService();
        var succeeded = 0;
        var failed = 0;
        var index = 0;

        foreach (var variant in variants)
        {
            cancellationToken.ThrowIfCancellationRequested();

            index++;

            var renderedJson = PlaceholderEngine.Apply(baseJson, variant);
            var variantName = string.Join("_", variant.Select(x => $"{x.Key}-{x.Value}"));

            var tempProfilePath = Path.Combine(
                renderedDirectory,
                $"matrix_{index:000}_{Sanitize(variantName)}.json");

            await File.WriteAllTextAsync(tempProfilePath, renderedJson, cancellationToken);

            Console.WriteLine($"[{index}/{variants.Count}] Running variant: {variantName}");

            var runArgs = new CliArguments
            {
                Command = CommandNames.Run,
                ProfilePath = tempProfilePath,
                DisableReports = args.DisableReports,
                DisableSqlOutput = args.DisableSqlOutput,
                OutputDirectoryOverride = args.OutputDirectoryOverride
            };

            var exitCode = await runService.ExecuteAsync(runArgs, cancellationToken);

            if (exitCode == 0)
                succeeded++;
            else
                failed++;
        }

        Console.WriteLine();
        Console.WriteLine("=== MATRIX SUMMARY ===");
        Console.WriteLine($"Succeeded : {succeeded}");
        Console.WriteLine($"Failed    : {failed}");

        return failed == 0 ? 0 : 1;
    }

    private static string Sanitize(string value)
    {
        var invalid = Path.GetInvalidFileNameChars();
        return new string(value.Select(ch => invalid.Contains(ch) ? '_' : ch).ToArray());
    }
}