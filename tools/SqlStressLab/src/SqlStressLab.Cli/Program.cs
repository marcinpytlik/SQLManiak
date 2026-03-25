using SqlStressLab.Core.CLI;
using SqlStressLab.Core.Models;
using SqlStressLab.Core.Services;

var cts = new CancellationTokenSource();

Console.CancelKeyPress += (_, e) =>
{
    e.Cancel = true;
    cts.Cancel();
};

try
{
    if (args.Length == 0 || IsHelpCommand(args))
    {
        PrintHelp();
        return 0;
    }

    var cliArgs = ParseArguments(args);

    var dispatcher = new CommandDispatcher(
        new RunCommandService(),
        new CompareCommandService(),
        new TrendCommandService());

    return await dispatcher.DispatchAsync(cliArgs, cts.Token);
}
catch (OperationCanceledException)
{
    Console.WriteLine("Anulowano.");
    return 10;
}
catch (Exception ex)
{
    Console.WriteLine("Błąd krytyczny:");
    Console.WriteLine(ex.Message);
    return 99;
}

static CliArguments ParseArguments(string[] args)
{
    if (args.Length == 1)
    {
        return new CliArguments
        {
            Command = "run",
            ProfilePath = args[0]
        };
    }

    var command = args[0].Trim().ToLowerInvariant();

    if (command is "run" or "compare" or "trend")
    {
        var result = new CliArguments
        {
            Command = command
        };

        switch (command)
        {
            case "run":
                if (args.Length < 2)
                    throw new InvalidOperationException("Brak ścieżki do profilu dla komendy 'run'.");

                result.ProfilePath = args[1];
                break;

            case "compare":
                // Wariant A:
                //   compare <profil.json>
                // Wariant B:
                //   compare --current <RunId> --baseline <RunId> --profile <ProfileName>
                if (args.Length >= 2 && !args[1].StartsWith("-"))
                {
                    result.ProfilePath = args[1];
                }
                else
                {
                    result.CurrentRunId = GetOption(args, "--current");
                    result.BaselineRunId = GetOption(args, "--baseline");
                    result.ProfileName = GetOption(args, "--profile");
                    result.IncludeSampleLevelDiff = HasFlag(args, "--sample-diff");
                }
                break;

            case "trend":
                // Wariant A:
                //   trend <profil.json>
                // Wariant B:
                //   trend --profile <ProfileName> --top 10
                if (args.Length >= 2 && !args[1].StartsWith("-"))
                {
                    result.ProfilePath = args[1];
                }
                else
                {
                    result.ProfileName = GetOption(args, "--profile");
                    var topRaw = GetOption(args, "--top");

                    if (int.TryParse(topRaw, out var top) && top > 0)
                    {
                        result.Top = top;
                    }
                }
                break;
        }

        return result;
    }

    // kompatybilność wsteczna:
    // SqlStressLab.Cli.exe .\profiles\demo-select.json
    return new CliArguments
    {
        Command = "run",
        ProfilePath = args[0]
    };
}

static string? GetOption(string[] args, string optionName)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        if (string.Equals(args[i], optionName, StringComparison.OrdinalIgnoreCase))
        {
            return args[i + 1];
        }
    }

    return null;
}

static bool HasFlag(string[] args, string flagName)
{
    return args.Any(x => string.Equals(x, flagName, StringComparison.OrdinalIgnoreCase));
}

static bool IsHelpCommand(string[] args)
{
    if (args.Length == 0)
        return true;

    var first = args[0].Trim().ToLowerInvariant();
    return first is "help" or "--help" or "-h" or "/?";
}

static void PrintHelp()
{
    Console.WriteLine("=== SQL STRESS LAB ===");
    Console.WriteLine();
    Console.WriteLine("Użycie:");
    Console.WriteLine("  SqlStressLab.Cli.exe <profil.json>");
    Console.WriteLine("  SqlStressLab.Cli.exe run <profil.json>");
    Console.WriteLine("  SqlStressLab.Cli.exe compare <profil.json>");
    Console.WriteLine("  SqlStressLab.Cli.exe trend <profil.json>");
    Console.WriteLine();
    Console.WriteLine("Zaawansowane:");
    Console.WriteLine("  SqlStressLab.Cli.exe compare --current <RunId> --baseline <RunId> --profile <ProfileName>");
    Console.WriteLine("  SqlStressLab.Cli.exe trend --profile <ProfileName> --top 10");
    Console.WriteLine();
    Console.WriteLine("Komendy:");
    Console.WriteLine("  run      - uruchamia workload na podstawie profilu");
    Console.WriteLine("  compare  - wykonuje compare na podstawie profilu albo jawnych RunId");
    Console.WriteLine("  trend    - wykonuje trend na podstawie profilu albo nazwy profilu");
    Console.WriteLine("  help     - pokazuje tę pomoc");
    Console.WriteLine();
    Console.WriteLine("Przykłady:");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe .\profiles\demo-select.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe run .\profiles\demo-proc.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe compare .\profiles\demo-select-sqloutput-separate.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe trend .\profiles\demo-select-sqloutput-separate.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe compare --current RUN_20260324_225024916 --baseline RUN_20260324_224500111 --profile demo-select");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe trend --profile demo-select --top 10");
    Console.WriteLine();
    Console.WriteLine("Zmienne środowiskowe:");
    Console.WriteLine("  SQLSTRESSLAB_PASSWORD   - hasło dla SqlPassword auth");
    Console.WriteLine();
    Console.WriteLine("Ważne katalogi:");
    Console.WriteLine(@"  profiles\   - profile JSON i pliki session/setup/cleanup");
    Console.WriteLine(@"  outputs\    - JSON/CSV/MD/HTML generowane przez aplikację");
    Console.WriteLine();
    Console.WriteLine("Przykład ustawienia hasła:");
    Console.WriteLine(@"  $env:SQLSTRESSLAB_PASSWORD = ""TwojeHaslo""");
    Console.WriteLine();
}