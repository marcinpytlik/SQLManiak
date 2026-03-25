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

    if (IsVersionCommand(args))
    {
        PrintVersion();
        return 0;
    }

    var cliArgs = ParseArguments(args);
    ValidateCliArguments(cliArgs);

    if (string.Equals(cliArgs.Command, CommandNames.Validate, StringComparison.OrdinalIgnoreCase))
    {
        return await ExecuteValidateAsync(cliArgs, cts.Token);
    }

  var dispatcher = new CommandDispatcher(
    new RunCommandService(),
    new CompareCommandService(),
    new TrendCommandService(),
    new ListRunsCommandService(),
    new DiagnosticsCommandService(),
    new SelfCheckCommandService(),
    new ListEnvironmentsCommandService(),
    new ListScenarioPacksCommandService(),
    new RenderCommandService(),
    new RunTemplateCommandService(),
    new RunMatrixCommandService());

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

    if (args.Length == 1 && LooksLikeProfilePath(args[0]))
    {
        return new CliArguments
        {
            Command = CommandNames.Run,
            ProfilePath = args[0]
        };
    }

    var command = NormalizeCommand(args[0]);

    return command switch
    {
        CommandNames.Run => ParseRunArguments(args),
        CommandNames.Compare => ParseCompareArguments(args),
        CommandNames.Trend => ParseTrendArguments(args),
        CommandNames.Validate => ParseValidateArguments(args),

        CommandNames.Batch => ParseProfileBasedCommand(args, CommandNames.Batch),
        CommandNames.Runbook => ParseProfileBasedCommand(args, CommandNames.Runbook),
        CommandNames.Bundle => ParseProfileBasedCommand(args, CommandNames.Bundle),
        CommandNames.PublishBundle => ParseProfileBasedCommand(args, CommandNames.PublishBundle),
        CommandNames.RunTemplate => ParseProfileBasedCommand(args, CommandNames.RunTemplate),
        CommandNames.RunMatrix => ParseProfileBasedCommand(args, CommandNames.RunMatrix),
        CommandNames.Render => ParseProfileBasedCommand(args, CommandNames.Render),
        CommandNames.Diagnostics => ParseProfileBasedCommand(args, CommandNames.Diagnostics),
        CommandNames.SelfCheck => ParseProfileBasedCommand(args, CommandNames.SelfCheck),

        CommandNames.ListRuns => ParseListRunsArguments(args),
        CommandNames.ListEnvironments => new CliArguments { Command = CommandNames.ListEnvironments },
        CommandNames.ListScenarioPacks => new CliArguments { Command = CommandNames.ListScenarioPacks },

        "help" => new CliArguments { Command = "help" },
        "version" => new CliArguments { Command = "version" },
        _ => throw new ArgumentException($"Nieznana komenda: {args[0]}")
    };
}

static CliArguments ParseRunArguments(string[] args)
{
    var result = new CliArguments { Command = CommandNames.Run };

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
    var result = new CliArguments { Command = CommandNames.Compare };

    if (args.Length == 2 && !args[1].StartsWith('-') && LooksLikeProfilePath(args[1]))
    {
        result.ProfilePath = args[1];
        return result;
    }

    if (HasAnyOption(args, "--profile", "-p"))
        result.ProfilePath = RequireOption(args, "--profile", "-p");

    result.CurrentRunId = GetOption(args, "--current");
    result.BaselineRunId = GetOption(args, "--baseline");
    result.ProfileName = GetOption(args, "--profile-name");
    result.IncludeSampleLevelDiff = HasFlag(args, "--sample-diff");
    result.OutputDirectoryOverride = GetOption(args, "--output-dir");
    result.DisableReports = HasFlag(args, "--no-reports");

    return result;
}

static CliArguments ParseTrendArguments(string[] args)
{
    var result = new CliArguments
    {
        Command = CommandNames.Trend,
        Top = 10
    };

    if (args.Length == 2 && !args[1].StartsWith('-') && LooksLikeProfilePath(args[1]))
    {
        result.ProfilePath = args[1];
        return result;
    }

    if (HasAnyOption(args, "--profile", "-p"))
        result.ProfilePath = RequireOption(args, "--profile", "-p");

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

    return result;
}

static CliArguments ParseValidateArguments(string[] args)
{
    var result = new CliArguments { Command = CommandNames.Validate };

    if (args.Length == 2 && !args[1].StartsWith('-') && LooksLikeProfilePath(args[1]))
    {
        result.ProfilePath = args[1];
        return result;
    }

    result.ProfilePath = RequireOption(args, "--profile", "-p");
    return result;
}

static CliArguments ParseProfileBasedCommand(string[] args, string commandName)
{
    var result = new CliArguments { Command = commandName };

    if (args.Length == 2 && !args[1].StartsWith('-') && LooksLikeProfilePath(args[1]))
    {
        result.ProfilePath = args[1];
        return result;
    }

    if (HasAnyOption(args, "--profile", "-p"))
        result.ProfilePath = RequireOption(args, "--profile", "-p");

    result.OutputDirectoryOverride = GetOption(args, "--output-dir");
    result.DisableReports = HasFlag(args, "--no-reports");

    return result;
}

static CliArguments ParseListRunsArguments(string[] args)
{
    var result = new CliArguments { Command = CommandNames.ListRuns };

    if (HasAnyOption(args, "--profile", "-p"))
        result.ProfilePath = RequireOption(args, "--profile", "-p");

    result.ProfileName = GetOption(args, "--profile-name");

    var topRaw = GetOption(args, "--top");
    if (!string.IsNullOrWhiteSpace(topRaw) && int.TryParse(topRaw, out var top) && top > 0)
        result.Top = top;
    else
        result.Top = 20;

    return result;
}

static void ValidateCliArguments(CliArguments args)
{
    ArgumentNullException.ThrowIfNull(args);

    var command = (args.Command ?? CommandNames.Run).Trim().ToLowerInvariant();

    switch (command)
    {
        case CommandNames.Run:
        case CommandNames.Validate:
        case CommandNames.Batch:
        case CommandNames.Runbook:
        case CommandNames.Bundle:
        case CommandNames.PublishBundle:
        case CommandNames.RunTemplate:
        case CommandNames.RunMatrix:
        case CommandNames.Render:
        case CommandNames.Diagnostics:
        case CommandNames.SelfCheck:
            if (string.IsNullOrWhiteSpace(args.ProfilePath))
                throw new ArgumentException($"Komenda '{command}' wymaga ProfilePath.");
            break;

        case CommandNames.Compare:
            if (string.IsNullOrWhiteSpace(args.ProfilePath) &&
                (string.IsNullOrWhiteSpace(args.CurrentRunId) || string.IsNullOrWhiteSpace(args.BaselineRunId)))
            {
                throw new ArgumentException(
                    "Komenda 'compare' wymaga albo ProfilePath, albo CurrentRunId + BaselineRunId.");
            }
            break;

        case CommandNames.Trend:
            if (string.IsNullOrWhiteSpace(args.ProfilePath) &&
                string.IsNullOrWhiteSpace(args.ProfileName))
            {
                throw new ArgumentException(
                    "Komenda 'trend' wymaga albo ProfilePath, albo ProfileName.");
            }

            if (args.Top <= 0)
                throw new ArgumentException("Parametr Top musi być większy od 0.");
            break;

        case CommandNames.ListRuns:
            if (args.Top <= 0)
                args.Top = 20;
            break;
    }
}

static async Task<int> ExecuteValidateAsync(CliArguments cliArgs, CancellationToken cancellationToken)
{
    if (string.IsNullOrWhiteSpace(cliArgs.ProfilePath))
        throw new ArgumentException("Komenda 'validate' wymaga ścieżki do profilu.");

    var fullProfilePath = Path.GetFullPath(cliArgs.ProfilePath);

    if (!File.Exists(fullProfilePath))
        throw new FileNotFoundException($"Brak pliku profilu: {fullProfilePath}");

    var json = await File.ReadAllTextAsync(fullProfilePath, cancellationToken);

    var config = System.Text.Json.JsonSerializer.Deserialize<RootConfig>(
        json,
        new System.Text.Json.JsonSerializerOptions { PropertyNameCaseInsensitive = true });

    if (config is null)
        throw new InvalidOperationException("Nie udało się zdeserializować konfiguracji.");

    Console.WriteLine("=== SQL STRESS LAB / VALIDATE ===");
    Console.WriteLine($"Profile file     : {fullProfilePath}");
    Console.WriteLine($"ProfileName      : {config.ProfileName}");
    Console.WriteLine($"ScenarioName     : {config.ScenarioName}");
    Console.WriteLine($"Server           : {config.Connection.Server}");
    Console.WriteLine($"Database         : {config.Connection.Database}");
    Console.WriteLine($"Authentication   : {config.Connection.Authentication}");
    Console.WriteLine($"CommandType      : {config.Execution.CommandType}");
    Console.WriteLine($"ExecutionMode    : {config.Execution.ExecutionMode}");
    Console.WriteLine($"Workers          : {config.Execution.Workers}");
    Console.WriteLine($"Iterations       : {config.Execution.IterationsPerWorker}");
    Console.WriteLine($"Session file     : {config.Execution.SessionSettingsFile}");
    Console.WriteLine($"SQL Output       : {config.SqlOutput.Enabled}");
    Console.WriteLine($"Compare Enabled  : {config.Compare.Enabled}");
    Console.WriteLine($"Trend Enabled    : {config.Trend.Enabled}");
    Console.WriteLine($"Bundle Enabled   : {config.Bundle.Enabled}");
    Console.WriteLine($"PublishBundle    : {config.PublishBundle.Enabled}");
    Console.WriteLine();
    Console.WriteLine("Walidacja profilu zakończona powodzeniem.");

    return 0;
}

static string NormalizeCommand(string command)
{
    return command.Trim().ToLowerInvariant() switch
    {
        "run" => CommandNames.Run,
        "compare" => CommandNames.Compare,
        "trend" => CommandNames.Trend,
        "validate" => CommandNames.Validate,
        "batch" => CommandNames.Batch,
        "runbook" => CommandNames.Runbook,
        "bundle" => CommandNames.Bundle,
        "publish-bundle" => CommandNames.PublishBundle,
        "run-template" => CommandNames.RunTemplate,
        "run-matrix" => CommandNames.RunMatrix,
        "render" => CommandNames.Render,
        "diagnostics" => CommandNames.Diagnostics,
        "self-check" => CommandNames.SelfCheck,
        "list-runs" => CommandNames.ListRuns,
        "list-environments" => CommandNames.ListEnvironments,
        "list-scenario-packs" => CommandNames.ListScenarioPacks,
        "help" or "--help" or "-h" or "/?" => "help",
        "version" or "--version" or "-v" => "version",
        _ => command.Trim().ToLowerInvariant()
    };
}

static bool IsHelpCommand(string[] args)
{
    if (args.Length == 0) return true;
    var first = args[0].Trim().ToLowerInvariant();
    return first is "help" or "--help" or "-h" or "/?";
}

static bool IsVersionCommand(string[] args)
{
    if (args.Length == 0) return false;
    var first = args[0].Trim().ToLowerInvariant();
    return first is "version" or "--version" or "-v";
}

static bool LooksLikeProfilePath(string value)
{
    return !string.IsNullOrWhiteSpace(value) &&
           value.EndsWith(".json", StringComparison.OrdinalIgnoreCase);
}

static string? GetOption(string[] args, params string[] names)
{
    for (var i = 0; i < args.Length - 1; i++)
    {
        foreach (var name in names)
        {
            if (string.Equals(args[i], name, StringComparison.OrdinalIgnoreCase))
                return args[i + 1];
        }
    }

    return null;
}

static string RequireOption(string[] args, params string[] names)
{
    var value = GetOption(args, names);
    if (string.IsNullOrWhiteSpace(value))
        throw new ArgumentException($"Brak wymaganego parametru {string.Join(" / ", names)}.");

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
    Console.WriteLine("Version: 1.0.0-sprint10");
    Console.WriteLine(".NET CLI shell for SQL Server stress, compare, trend, validation and advanced orchestration");
}

static void PrintHelp()
{
    Console.WriteLine("=== SQL STRESS LAB ===");
    Console.WriteLine();
    Console.WriteLine("Komendy podstawowe:");
    Console.WriteLine("  run");
    Console.WriteLine("  compare");
    Console.WriteLine("  trend");
    Console.WriteLine("  validate");
    Console.WriteLine();
    Console.WriteLine("Komendy Sprint 10:");
    Console.WriteLine("  batch");
    Console.WriteLine("  runbook");
    Console.WriteLine("  bundle");
    Console.WriteLine("  publish-bundle");
    Console.WriteLine("  run-template");
    Console.WriteLine("  run-matrix");
    Console.WriteLine("  render");
    Console.WriteLine("  diagnostics");
    Console.WriteLine("  self-check");
    Console.WriteLine("  list-runs");
    Console.WriteLine("  list-environments");
    Console.WriteLine("  list-scenario-packs");
    Console.WriteLine();
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe run .\profiles\demo-select.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe compare .\profiles\demo-select.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe trend .\profiles\demo-select.json --top 15");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe validate .\profiles\demo-select.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe batch --profile .\profiles\batch.json");
    Console.WriteLine(@"  .\SqlStressLab.Cli.exe runbook --profile .\profiles\runbook.json");
    Console.WriteLine();
}