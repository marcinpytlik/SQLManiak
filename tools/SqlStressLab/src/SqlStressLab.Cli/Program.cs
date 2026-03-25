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
    if (args.Length == 0)
    {
        PrintHelp();
        return 0;
    }

    if (IsHelpCommand(args))
    {
        PrintHelp();
        return 0;
    }

    if (IsVersionCommand(args))
    {
        PrintVersion();
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
catch (ArgumentException ex)
{
    Console.WriteLine("Błąd argumentów:");
    Console.WriteLine(ex.Message);
    Console.WriteLine();
    PrintHelp();
    return 2;
}
catch (InvalidOperationException ex)
{
    Console.WriteLine("Błąd operacji:");
    Console.WriteLine(ex.Message);
    return 3;
}
catch (Exception ex)
{
    Console.WriteLine("Błąd krytyczny:");
    Console.WriteLine(ex.Message);
    return 99;
}

static CliArguments ParseArguments(string[] args)
{
    if (args is null || args.Length == 0)
        throw new ArgumentException("Nie podano argumentów.");

    // tryb zgodności wstecznej:
    //   SqlStressLab.Cli.exe .\profiles\demo-select.json
    if (args.Length == 1 && LooksLikeProfilePath(args[0]))
    {
        return new CliArguments
        {
            Command = "run",
            ProfilePath = args[0]
        };
    }

    var command = NormalizeCommand(args[0]);

    return command switch
    {
        "run" => ParseRunArguments(args),
        "compare" => ParseCompareArguments(args),
        "trend" => ParseTrendArguments(args),
        "help" => new CliArguments { Command = "help" },
        "version" => new CliArguments { Command = "version" },
        _ => throw new ArgumentException($"Nieznana komenda: {args[0]}")
    };
}

static CliArguments ParseRunArguments(string[] args)
{
    var result = new CliArguments
    {
        Command = "run"
    };

    if (args.Length == 2 && !args[1].StartsWith('-') && LooksLikeProfilePath(args[1]))
    {
        result.ProfilePath = args[1];
        return result;
    }

    result.ProfilePath = RequireOption(args, "--profile", "-p");
    result.OutputDirectoryOverride = GetOption(args, "--output-dir");
    result.DisableSqlOutput = HasFlag(args, "--no-sql-output");
    result.DisableReports = HasFlag(args, "--no-reports");

    return result;
}

static CliArguments ParseCompareArguments(string[] args)
{
    var result = new CliArguments
    {
        Command = "compare"
    };

    // wariant 1:
    //   compare .\profiles\demo.json
    if (args.Length == 2 && !args[1].StartsWith('-') && LooksLikeProfilePath(args[1]))
    {
        result.ProfilePath = args[1];
        return result;
    }

    // wariant 2:
    //   compare --profile .\profiles\demo.json
    if (HasAnyOption(args, "--profile", "-p"))
    {
        result.ProfilePath = RequireOption(args, "--profile", "-p");
    }

    result.CurrentRunId = GetOption(args, "--current");
    result.BaselineRunId = GetOption(args, "--baseline");
    result.ProfileName = GetOption(args, "--profile-name");
    result.IncludeSampleLevelDiff = HasFlag(args, "--sample-diff");
    result.OutputDirectoryOverride = GetOption(args, "--output-dir");
    result.DisableReports = HasFlag(args, "--no-reports");

    if (string.IsNullOrWhiteSpace(result.ProfilePath) &&
        (string.IsNullOrWhiteSpace(result.CurrentRunId) || string.IsNullOrWhiteSpace(result.BaselineRunId)))
    {
        throw new ArgumentException(
            "Komenda 'compare' wymaga albo ścieżki do profilu, albo pary --current i --baseline.");
    }

    return result;
}

static CliArguments ParseTrendArguments(string[] args)
{
    var result = new CliArguments
    {
        Command = "trend",
        Top = 10
    };

    // wariant 1:
    //   trend .\profiles\demo.json
    if (args.Length == 2 && !args[1].StartsWith('-') && LooksLikeProfilePath(args[1]))
    {
        result.ProfilePath = args[1];
        return result;
    }

    // wariant 2:
    //   trend --profile .\profiles\demo.json --top 15
    if (HasAnyOption(args, "--profile", "-p"))
    {
        result.ProfilePath = RequireOption(args, "--profile", "-p");
    }

    result.ProfileName = GetOption(args, "--profile-name");
    result.OutputDirectoryOverride = GetOption(args, "--output-dir");
    result.DisableReports = HasFlag(args, "--no-reports");

    var topRaw = GetOption(args, "--top");
    if (!string.IsNullOrWhiteSpace(topRaw))
    {
        if (!int.TryParse(topRaw, out var top) || top <= 0)
            throw new ArgumentException("Parametr --top musi być dodatnią liczbą całkowitą.");

        result.Top = top;
    }

    if (string.IsNullOrWhiteSpace(result.ProfilePath) && string.IsNullOrWhiteSpace(result.ProfileName))
    {
        throw new ArgumentException(
            "Komenda 'trend' wymaga albo ścieżki do profilu, albo --profile-name.");
    }

    return result;
}

static string NormalizeCommand(string command)
{
    return command.Trim().ToLowerInvariant() switch
    {
        "run" => "run",
        "compare" => "compare",
        "trend" => "trend",
        "help" or "--help" or "-h" or "/?" => "help",
        "version" or "--version" or "-v" => "version",
        _ => command.Trim().ToLowerInvariant()
    };
}

static bool IsHelpCommand(string[] args)
{
    if (args.Length == 0)
        return true;

    var first = args[0].Trim().ToLowerInvariant();
    return first is "help" or "--help" or "-h" or "/?";
}

static bool IsVersionCommand(string[] args)
{
    if (args.Length == 0)
        return false;

    var first = args[0].Trim().ToLowerInvariant();
    return first is "version" or "--version" or "-v";
}

static bool LooksLikeProfilePath(string value)
{
    if (string.IsNullOrWhiteSpace(value))
        return false;

    return value.EndsWith(".json", StringComparison.OrdinalIgnoreCase);
}

static string? GetOption(string[] args, params string[] names)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        foreach (var name in names)
        {
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
            {
                return args[i + 1];
            }
        }
    }

    return null;
}

static string RequireOption(string[] args, params string[] names)
{
    var value = GetOption(args, names);
    if (string.IsNullOrWhiteSpace(value))
    {
        var joined = string.Join(" / ", names);
        throw new ArgumentException($"Brak wymaganego parametru {joined}.");
    }

    return value;
}

static bool HasFlag(string[] args, string flagName)
{
    return args.Any(x => string.Equals(x, flagName, StringComparison.OrdinalIgnoreCase));
}

static bool HasAnyOption(string[] args, params string[] names)
{
    return names.Any(name => args.Any(x => string.Equals(x, name, StringComparison.OrdinalIgnoreCase)));
}

static void PrintVersion()
{
    Console.WriteLine("SqlStressLab");
    Console.WriteLine("Version: 0.8.0");
    Console.WriteLine(".NET CLI shell for SQL Server stress, compare and trend analysis");
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
    Console.WriteLine("Komendy:");
    Console.WriteLine("  run       - uruchamia workload");
    Console.WriteLine("  compare   - porównuje current run z baseline");
    Console.WriteLine("  trend     - liczy trend ostatnich runów");
    Console.WriteLine("  help      - pokazuje pomoc");
    Console.WriteLine("  version   - pokazuje wersję");
    Console.WriteLine();
    Console.WriteLine("Run:");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe run .\profiles\demo-select.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe run --profile .\profiles\demo-proc.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe run --profile .\profiles\demo-blocking.json --output-dir .\outputs");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe run --profile .\profiles\demo-select.json --no-sql-output");
    Console.WriteLine();
    Console.WriteLine("Compare:");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe compare .\profiles\demo-select-sqloutput-separate.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe compare --profile .\profiles\demo-select-sqloutput-separate.json --sample-diff");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe compare --profile .\profiles\demo-select-sqloutput-separate.json --current RUN_1 --baseline RUN_0");
    Console.WriteLine();
    Console.WriteLine("Trend:");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe trend .\profiles\demo-select-sqloutput-separate.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe trend --profile .\profiles\demo-select-sqloutput-separate.json --top 15");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe trend --profile-name demo-select --profile .\profiles\demo-select-sqloutput-separate.json --top 20");
    Console.WriteLine();
    Console.WriteLine("Flagi dodatkowe:");
    Console.WriteLine("  --profile / -p      ścieżka do profilu JSON");
    Console.WriteLine("  --current           RunId bieżącego runu");
    Console.WriteLine("  --baseline          RunId baseline");
    Console.WriteLine("  --profile-name      nazwa profilu do repo");
    Console.WriteLine("  --top               liczba runów do trendu");
    Console.WriteLine("  --sample-diff       włącza sample level diff");
    Console.WriteLine("  --output-dir        nadpisuje katalog wyjściowy");
    Console.WriteLine("  --no-sql-output     wyłącza zapis do SQL Server");
    Console.WriteLine("  --no-reports        wyłącza raporty plikowe");
    Console.WriteLine();
    Console.WriteLine("Zmienne środowiskowe:");
    Console.WriteLine("  SQLSTRESSLAB_PASSWORD   - hasło dla SqlPassword auth");
    Console.WriteLine();
    Console.WriteLine("Katalogi:");
    Console.WriteLine(@"  profiles\   - profile JSON, session.sql, setup/cleanup");
    Console.WriteLine(@"  outputs\    - JSON/CSV/MD/HTML");
    Console.WriteLine();
    Console.WriteLine("Przykład ustawienia hasła:");
    Console.WriteLine(@"  $env:SQLSTRESSLAB_PASSWORD = ""TwojeHaslo""");
    Console.WriteLine();
}