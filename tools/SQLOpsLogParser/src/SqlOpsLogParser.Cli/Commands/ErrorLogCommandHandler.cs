using Spectre.Console;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Cli.Commands;

public sealed class ErrorLogCommandHandler(
    IProfileProvider profileProvider,
    IErrorLogRepository errorLogRepository,
    IErrorLogReader errorLogReader)
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
            "read" => await HandleReadAsync(args),
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

    private async Task<int> HandleReadAsync(string[] args)
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

        var logValue = GetOptionValue(args, "--log");
        var contains = GetOptionValue(args, "--contains");
        var fromValue = GetOptionValue(args, "--from");
        var toValue = GetOptionValue(args, "--to");
        var topValue = GetOptionValue(args, "--top");

        var request = new ErrorLogReadRequest
        {
            Profile = profile,
            LogNumber = 0,
            ContainsText = contains
        };

        if (!string.IsNullOrWhiteSpace(logValue))
        {
            if (!int.TryParse(logValue, out var logNumber) || logNumber < 0)
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --log[/]");
                return 4;
            }

            request.LogNumber = logNumber;
        }

        if (!string.IsNullOrWhiteSpace(fromValue))
        {
            if (!DateTime.TryParse(fromValue, out var fromDate))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --from[/]");
                return 4;
            }

            request.From = fromDate;
        }

        if (!string.IsNullOrWhiteSpace(toValue))
        {
            if (!DateTime.TryParse(toValue, out var toDate))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --to[/]");
                return 4;
            }

            request.To = toDate;
        }

        if (request.From.HasValue && request.To.HasValue && request.From > request.To)
        {
            AnsiConsole.MarkupLine("[red]Parametr --from nie może być większy niż --to[/]");
            return 4;
        }

        if (!string.IsNullOrWhiteSpace(topValue))
        {
            if (!int.TryParse(topValue, out var top) || top <= 0)
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --top[/]");
                return 4;
            }

            request.Top = top;
        }

        var entries = await errorLogReader.ReadAsync(request);

        if (entries.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak wpisów w logu dla podanych filtrów.[/]");
            return 3;
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("LogDate");
        table.AddColumn("ProcessInfo");
        table.AddColumn("Text");

        foreach (var entry in entries)
        {
            table.AddRow(
                  Markup.Escape(entry.LogDate.ToString("yyyy-MM-dd HH:mm:ss")),
        Markup.Escape(entry.ProcessInfo),
        Markup.Escape(Truncate(entry.Text, 140)));
        }

        AnsiConsole.Write(table);
        return 0;
    }

    private static string FormatMegabytes(long bytes)
    {
        var mb = bytes / 1024d / 1024d;
        return mb.ToString("0.00");
    }

    private static string Truncate(string value, int maxLength)
    {
        if (string.IsNullOrEmpty(value) || value.Length <= maxLength)
        {
            return value;
        }

        return value[..maxLength] + "...";
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
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --log 1[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --contains \"Login failed\"[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --top 50[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --from \"2026-03-22 00:00\" --to \"2026-03-22 23:59\"[/]");
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