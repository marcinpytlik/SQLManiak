using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class ListScenarioPacksCommandService
{
    public async Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        if (string.IsNullOrWhiteSpace(args.ProfilePath))
            throw new InvalidOperationException(
                "Dla komendy 'list-scenario-packs' wymagany jest profil JSON.");

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

        Console.WriteLine("=== SQL STRESS LAB / LIST-SCENARIO-PACKS ===");
        Console.WriteLine($"Profile file : {fullProfilePath}");
        Console.WriteLine();

        if (config.ScenarioPacks is null || config.ScenarioPacks.Count == 0)
        {
            Console.WriteLine("Brak zdefiniowanych scenario packów.");
            return 0;
        }

        foreach (var pack in config.ScenarioPacks.OrderBy(x => x.Name))
        {
            Console.WriteLine($"Pack: {pack.Name}");

            if (!string.IsNullOrWhiteSpace(pack.Description))
            {
                Console.WriteLine($"  Description: {pack.Description}");
            }

            if (pack.ScenarioNames.Count == 0)
            {
                Console.WriteLine("  Scenarios: <empty>");
            }
            else
            {
                Console.WriteLine("  Scenarios:");
                foreach (var scenario in pack.ScenarioNames)
                {
                    Console.WriteLine($"    - {scenario}");
                }
            }

            Console.WriteLine();
        }

        return 0;
    }
}