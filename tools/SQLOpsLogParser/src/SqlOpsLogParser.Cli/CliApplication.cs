using Spectre.Console;
using SqlOpsLogParser.Cli.Commands;

namespace SqlOpsLogParser.Cli;

public sealed class CliApplication(
    ProfilesCommandHandler profilesCommandHandler,
    ErrorLogCommandHandler errorLogCommandHandler)
{
    public async Task<int> RunAsync(string[] args)
    {
        if (args.Length == 0 || args.Contains("--help") || args.Contains("-h"))
        {
            ShowHelp();
            return 0;
        }

        var command = args[0].ToLowerInvariant();

        return command switch
        {
            "profiles" => await profilesCommandHandler.HandleAsync(args),
            "errorlog" => await errorLogCommandHandler.HandleAsync(args),
            _ => HandleUnknownCommand()
        };
    }

    private static int HandleUnknownCommand()
    {
        AnsiConsole.MarkupLine("[red]Unknown command.[/]");
        ShowHelp();
        return 4;
    }

    private static void ShowHelp()
    {
        AnsiConsole.Write(new Rule("[yellow]SqlOpsLogParser[/]"));
        AnsiConsole.MarkupLine("Available commands:");
        AnsiConsole.MarkupLine("  [green]profiles list[/]");
        AnsiConsole.MarkupLine("  [green]profiles show --name LOCALDEV[/]");
        AnsiConsole.MarkupLine("  [green]profiles test --name LOCALDEV[/]");
        AnsiConsole.MarkupLine("  [green]errorlog list --name LOCALDEV[/]");
        AnsiConsole.MarkupLine("  [green]errorlog list --name LOCALDEV --top 5[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV[/]");
AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --log 1[/]");
AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --contains \"Login failed\"[/]");
AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --top 50[/]");
    }
}