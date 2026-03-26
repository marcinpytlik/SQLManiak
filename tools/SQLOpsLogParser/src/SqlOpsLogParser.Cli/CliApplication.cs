using Spectre.Console;

namespace SqlOpsLogParser.Cli;

public sealed class CliApplication
{
    public Task<int> RunAsync(string[] args)
    {
        if (args.Length == 0 || args.Contains("--help") || args.Contains("-h"))
        {
            ShowHelp();
            return Task.FromResult(0);
        }

        AnsiConsole.MarkupLine("[red]Unknown command.[/]");
        ShowHelp();
        return Task.FromResult(4);
    }

    private static void ShowHelp()
    {
        AnsiConsole.Write(new Rule("[yellow]SqlOpsLogParser[/]"));
        AnsiConsole.MarkupLine("Available commands:");
        AnsiConsole.MarkupLine("  [green]--help[/]");
    }
}