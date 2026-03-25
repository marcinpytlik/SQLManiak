using System.Diagnostics;
using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class PublishBundleCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException("Dla komendy 'publish-bundle' wymagany jest profil JSON.");

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

        if (!config.PublishBundle.Enabled)
            throw new InvalidOperationException("Sekcja PublishBundle jest wyłączona.");

        if (string.IsNullOrWhiteSpace(config.PublishBundle.OutputDirectory))
            throw new InvalidOperationException("PublishBundle.OutputDirectory jest wymagany.");

        var outputDirectory = Path.IsPathRooted(config.PublishBundle.OutputDirectory)
            ? config.PublishBundle.OutputDirectory
            : Path.GetFullPath(Path.Combine(rootDirectory, config.PublishBundle.OutputDirectory));

        Directory.CreateDirectory(outputDirectory);

        var solutionRoot = FindSolutionRoot(rootDirectory);
        var cliProject = Path.Combine(solutionRoot, "src", "SqlStressLab.Cli", "SqlStressLab.Cli.csproj");

        if (!File.Exists(cliProject))
            throw new FileNotFoundException($"Nie znaleziono projektu CLI: {cliProject}");

        var arguments =
            $"publish \"{cliProject}\" -c Release -r {config.PublishBundle.Runtime} " +
            $"-o \"{outputDirectory}\" " +
            $"--self-contained {config.PublishBundle.SelfContained.ToString().ToLowerInvariant()}";

        var psi = new ProcessStartInfo
        {
            FileName = "dotnet",
            Arguments = arguments,
            WorkingDirectory = solutionRoot,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = new Process { StartInfo = psi };

        process.Start();

        var stdout = await process.StandardOutput.ReadToEndAsync(cancellationToken);
        var stderr = await process.StandardError.ReadToEndAsync(cancellationToken);

        await process.WaitForExitAsync(cancellationToken);

        Console.WriteLine("=== SQL STRESS LAB / PUBLISH-BUNDLE ===");
        Console.WriteLine(stdout);

        if (!string.IsNullOrWhiteSpace(stderr))
        {
            Console.WriteLine(stderr);
        }

        if (process.ExitCode != 0)
            return process.ExitCode;

        if (config.PublishBundle.IncludeProfilesDirectory)
        {
            var sourceProfiles = Path.Combine(solutionRoot, "src", "SqlStressLab.Cli", "profiles");
            var targetProfiles = Path.Combine(outputDirectory, "profiles");

            if (Directory.Exists(sourceProfiles))
            {
                CopyDirectory(sourceProfiles, targetProfiles);
                Console.WriteLine($"Profiles copied to: {targetProfiles}");
            }
        }

        Console.WriteLine($"Publish output: {outputDirectory}");
        return 0;
    }

    private static string FindSolutionRoot(string startDirectory)
    {
        var current = new DirectoryInfo(startDirectory);

        while (current is not null)
        {
            if (Directory.Exists(Path.Combine(current.FullName, "src")))
                return current.FullName;

            current = current.Parent;
        }

        throw new InvalidOperationException("Nie udało się odnaleźć katalogu solution root.");
    }

    private static void CopyDirectory(string sourceDir, string targetDir)
    {
        Directory.CreateDirectory(targetDir);

        foreach (var file in Directory.GetFiles(sourceDir))
        {
            var targetFile = Path.Combine(targetDir, Path.GetFileName(file));
            File.Copy(file, targetFile, true);
        }

        foreach (var dir in Directory.GetDirectories(sourceDir))
        {
            var targetSubDir = Path.Combine(targetDir, Path.GetFileName(dir));
            CopyDirectory(dir, targetSubDir);
        }
    }
}