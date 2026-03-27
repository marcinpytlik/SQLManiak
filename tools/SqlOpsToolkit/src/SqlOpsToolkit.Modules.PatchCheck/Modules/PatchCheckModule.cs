using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Enums;
using SqlOpsToolkit.Infrastructure.Configuration;
using SqlOpsToolkit.Infrastructure.Sql;
using SqlOpsToolkit.Modules.PatchCheck.Commands;

namespace SqlOpsToolkit.Modules.PatchCheck;

public sealed class PatchCheckModule : IToolModule
{
    public string Name => "patch";

    public async Task<int> ExecuteAsync(string[] args, CancellationToken cancellationToken = default)
    {
        try
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

            var profileLoader = new JsonConnectionProfileLoader();
            var profileValidator = new ConnectionProfileValidator();
            var baselineLoader = new JsonPatchBaselineLoader();

            var connectionStringFactory = new SqlConnectionStringFactory();
            var connectionTester = new SqlConnectionTester(connectionStringFactory);
            var metadataReader = new SqlServerMetadataReader(connectionStringFactory);
            var evaluator = new PatchComplianceEvaluator();

            var profilesFile = await profileLoader.LoadAsync(options.ProfilesFile, cancellationToken);
            var baseline = await baselineLoader.LoadAsync(options.BaselineFile, cancellationToken);

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
                var validationErrors = profileValidator.Validate(profile);

                if (validationErrors.Count > 0)
                {
                    Console.WriteLine($"[INVALID] {profile.Name}");
                    foreach (var error in validationErrors)
                    {
                        Console.WriteLine($"  - {error}");
                    }
                    continue;
                }

                var connectionResult = await connectionTester.TestAsync(profile, cancellationToken);

                if (!connectionResult.ConnectOk)
                {
                    Console.WriteLine($"[ERR] {connectionResult.ProfileName} | {connectionResult.Server} | {connectionResult.Message}");
                    continue;
                }

                var metadata = await metadataReader.ReadAsync(profile, cancellationToken);
                var compliance = evaluator.Evaluate(metadata, baseline);

                var statusText = compliance.Status switch
                {
                    ComplianceStatus.Compliant => "COMPLIANT",
                    ComplianceStatus.Outdated => "OUTDATED",
                    ComplianceStatus.Unsupported => "UNSUPPORTED",
                    ComplianceStatus.Error => "ERROR",
                    _ => "UNKNOWN"
                };

                Console.WriteLine(
                    $"[{statusText}] {profile.Name} | {metadata.ServerName} | Detected={compliance.DetectedVersion} | Recommended={compliance.RecommendedBuild} | Label={compliance.RecommendedLabel}");
            }

            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[FATAL] {ex.Message}");
            return 1;
        }
    }

    private static void ShowHelp()
    {
        Console.WriteLine("Użycie:");
        Console.WriteLine("  sqlopstoolkit patch check --profiles-file <path> --baseline <path> [--profile <name>] [--tag <tag>]");
    }
}