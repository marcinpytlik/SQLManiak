using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class ListEnvironmentsCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException(
                "Dla komendy 'list-environments' wymagany jest profil JSON.");

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

        Console.WriteLine("=== SQL STRESS LAB / LIST-ENVIRONMENTS ===");
        Console.WriteLine($"Profile file : {fullProfilePath}");
        Console.WriteLine();

        if (config.Environments is null || config.Environments.Count == 0)
        {
            Console.WriteLine("Brak zdefiniowanych środowisk.");
            return 0;
        }

        Console.WriteLine(
            $"{Pad("Name", 20)} " +
            $"{Pad("Server", 24)} " +
            $"{Pad("Database", 18)} " +
            $"{Pad("Auth", 14)} " +
            $"{Pad("Tags", 30)}");

        Console.WriteLine(new string('-', 112));

        foreach (var env in config.Environments.OrderBy(x => x.Name))
        {
            Console.WriteLine(
                $"{Pad(env.Name, 20)} " +
                $"{Pad(env.Server, 24)} " +
                $"{Pad(env.Database, 18)} " +
                $"{Pad(env.Authentication, 14)} " +
                $"{Pad(string.Join(",", env.Tags), 30)}");

            if (!string.IsNullOrWhiteSpace(env.Description))
            {
                Console.WriteLine($"  Description: {env.Description}");
            }
        }

        return 0;
    }

    private static string Pad(string? value, int width)
        => (value ?? string.Empty).PadRight(width);
}