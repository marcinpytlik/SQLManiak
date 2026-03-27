using SqlOpsToolkit.Core.Abstractions;

namespace SqlOpsToolkit.Modules.PatchCheck;

public sealed class PatchCheckModule : IToolModule
{
    public string Name => "patch";

    public Task<int> ExecuteAsync(string[] args, CancellationToken cancellationToken = default)
    {
        if (args.Length == 0)
        {
            ShowHelp();
            return Task.FromResult(1);
        }

        var command = args[0];

        if (!string.Equals(command, "check", StringComparison.OrdinalIgnoreCase))
        {
            Console.WriteLine($"Nieznana komenda modułu patch: {command}");
            ShowHelp();
            return Task.FromResult(1);
        }

        Console.WriteLine("Uruchomiono: patch check");
        Console.WriteLine("Sprint 0: placeholder bez logiki biznesowej.");
        Console.WriteLine($"Argumenty dodatkowe: {string.Join(" ", args.Skip(1))}");

        return Task.FromResult(0);
    }

    private static void ShowHelp()
    {
        Console.WriteLine("Użycie:");
        Console.WriteLine("  sqlopstoolkit patch check [options]");
    }
}