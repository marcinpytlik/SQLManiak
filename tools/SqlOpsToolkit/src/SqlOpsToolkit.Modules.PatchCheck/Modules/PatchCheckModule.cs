using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Infrastructure.Configuration;
using SqlOpsToolkit.Infrastructure.Sql;
using SqlOpsToolkit.Modules.PatchCheck.Commands;

namespace SqlOpsToolkit.Modules.PatchCheck;

public sealed class PatchCheckModule : IToolModule
{
    public string Name => "patch";

    public async Task<int> ExecuteAsync(string[] args, CancellationToken cancellationToken = default)
    {
        if (args.Length == 0)
        {
            ShowHelp();
            return 1;
        }

        var command = args[0];

        if (!string.Equals(command, "check", StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine($"Nieznana komenda modułu patch: {command}");
            ShowHelp();
            return 1;
        }

        var options = PatchCheckOptionsParser.Parse(args.Skip(1).ToArray());

        var loader = new JsonConnectionProfileLoader();
        var validator = new ConnectionProfileValidator();
        var connectionStringFactory = new SqlConnectionStringFactory();
        var tester = new SqlConnectionTester(connectionStringFactory);

        var profilesFile = await loader.LoadAsync(options.ProfilesFile, cancellationToken);
        var selectedProfiles = ConnectionProfileSelector.Select(
            profilesFile.Profiles,
            options.ProfileName,
            options.Tag);

        if (selectedProfiles.Count == 0)
        {
            Console.WriteLine("Nie znaleziono żadnych profili spełniających kryteria.");
            return 1;
        }

        foreach (var profile in selectedProfiles)
        {
            var validationErrors = validator.Validate(profile);

            if (validationErrors.Count > 0)
            {
                Console.WriteLine($"[INVALID] {profile.Name}");
                foreach (var error in validationErrors)
                {
                    Console.WriteLine($"  - {error}");
                }
                continue;
            }

            var result = await tester.TestAsync(profile, cancellationToken);

            if (result.ConnectOk)
            {
                Console.WriteLine($"[OK] {result.ProfileName} | {result.Server} | {result.DurationMs} ms");
            }
            else
            {
                Console.WriteLine($"[ERR] {result.ProfileName} | {result.Server} | {result.Message}");
            }
        }

        return 0;
    }

    private static void ShowHelp()
    {
        Console.WriteLine("Użycie:");
        Console.WriteLine("  sqlopstoolkit patch check --profiles-file <path> [--profile <name>] [--tag <tag>]");
    }
}