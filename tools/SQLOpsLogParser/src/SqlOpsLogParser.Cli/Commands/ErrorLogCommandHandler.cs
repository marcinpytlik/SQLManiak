using Spectre.Console;
using SqlOpsLogParser.Core.Interfaces;

namespace SqlOpsLogParser.Cli.Commands;

public sealed class ErrorLogCommandHandler(
    IProfileProvider profileProvider,
    IErrorLogRepository errorLogRepository)
{
    public async Task<int> HandleAsync(string[] args)
    {
        if (args.Length < 2)
        {
            ShowHelp();
            return 4;
        }

        var subcommand = args[1].ToLowerInvariant();

        return subcommand switch
        {
            "list" => await HandleListAsync(args),
            _ => HandleUnknownSubcommand()
        };
    }

    private async Task<int> HandleListAsync(string[] args)
    {
        var name = GetOptionValue(args, "--name");

        if (string.IsNullOrWhiteSpace(name))
        {
            AnsiConsole.MarkupLine("[red]Brak parametru --name[/]");
            return 4;
        }

        var profile = profileProvider.GetByName(name);

        if (profile is null)
        {
            AnsiConsole.MarkupLine($"[red]Nie znaleziono profilu:[/] {name}");
            return 3;
        }

        var logs = await errorLogRepository.GetErrorLogsAsync(profile);

        if (logs.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak wpisów z listą errorlogów.[/]");
            return 3;
        }

        var topValue = GetOptionValue(args, "--top");
        if (int.TryParse(topValue, out var top) && top > 0)
        {
            logs = logs.Take(top).ToList();
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("ArchiveNumber");
        table.AddColumn("LogDate");
        table.AddColumn("SizeBytes");
        table.AddColumn("SizeMB");

        foreach (var log in logs)
        {
            table.AddRow(
                log.ArchiveNumber.ToString(),
                log.LogDate.ToString("yyyy-MM-dd HH:mm:ss"),
                log.LogFileSizeBytes.ToString(),
                FormatMegabytes(log.LogFileSizeBytes));
        }

        AnsiConsole.Write(table);
        return 0;
    }

    private static string FormatMegabytes(long bytes)
    {
        var mb = bytes / 1024d / 1024d;
        return mb.ToString("0.00");
    }

    private static int HandleUnknownSubcommand()
    {
        AnsiConsole.MarkupLine("[red]Nieznana subkomenda errorlog[/]");
        ShowHelp();
        return 4;
    }

    private static void ShowHelp()
    {
        AnsiConsole.MarkupLine("[yellow]Dostępne komendy:[/]");
        AnsiConsole.MarkupLine("  [green]errorlog list --name LOCALDEV[/]");
        AnsiConsole.MarkupLine("  [green]errorlog list --name LOCALDEV --top 5[/]");
    }

    private static string? GetOptionValue(string[] args, string optionName)
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
}