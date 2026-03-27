using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Modules.PatchCheck;

var cancellationToken = CancellationToken.None;

if (args.Length == 0)
{
    ShowHelp();
    return 1;
}

var modules = new Dictionary<string, IToolModule>(StringComparer.OrdinalIgnoreCase)
{
    ["patch"] = new PatchCheckModule()
};

var rootCommand = args[0];

if (!modules.TryGetValue(rootCommand, out var module))
{
    Console.WriteLine($"Nieznana komenda główna: {rootCommand}");
    ShowHelp();
    return 1;
}

var remainingArgs = args.Skip(1).ToArray();
return await module.ExecuteAsync(remainingArgs, cancellationToken);

static void ShowHelp()
{
    Console.WriteLine("SqlOpsToolkit");
    Console.WriteLine();
    Console.WriteLine("Użycie:");
    Console.WriteLine("  sqlopstoolkit <module> <command> [options]");
    Console.WriteLine();
    Console.WriteLine("Moduły:");
    Console.WriteLine("  patch        Patch compliance checker");
}