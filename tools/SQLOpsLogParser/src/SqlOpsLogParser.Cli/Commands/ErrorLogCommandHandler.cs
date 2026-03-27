using Spectre.Console;
using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Cli.Commands;

public sealed class ErrorLogCommandHandler(
    IProfileProvider profileProvider,
    IErrorLogRepository errorLogRepository,
    IErrorLogReader errorLogReader,
    IReportService reportService)
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
                Markup.Escape(log.ArchiveNumber.ToString()),
                Markup.Escape(log.LogDate.ToString("yyyy-MM-dd HH:mm:ss")),
                Markup.Escape(log.LogFileSizeBytes.ToString()),
                Markup.Escape(FormatMegabytes(log.LogFileSizeBytes)));
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
        var severityValue = GetOptionValue(args, "--severity");
        var categoryValue = GetOptionValue(args, "--category");
        var outValue = GetOptionValue(args, "--out");
        var formatValue = GetOptionValue(args, "--format");

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

        if (!string.IsNullOrWhiteSpace(severityValue))
        {
            if (!Enum.TryParse<EventSeverity>(severityValue, true, out var severity))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --severity[/]");
                return 4;
            }

            request.SeverityFilter = severity;
        }

        if (!string.IsNullOrWhiteSpace(categoryValue))
        {
            if (!Enum.TryParse<EventCategory>(categoryValue, true, out var category))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --category[/]");
                return 4;
            }

            request.CategoryFilter = category;
        }

        var entries = await errorLogReader.ReadAsync(request);

        if (entries.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak wpisów w logu dla podanych filtrów.[/]");
            return 3;
        }

        if (!string.IsNullOrWhiteSpace(outValue))
        {
            if (!TryParseFormat(formatValue, out var format))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --format[/]");
                return 4;
            }

            await reportService.WriteAsync(
                entries,
                new ReportRequest
                {
                    OutputPath = outValue,
                    Format = format,
                    Title = "ErrorLog Report",
                    Metadata = new Dictionary<string, string>
                    {
                        ["Profile"] = profile.Name,
                        ["LogNumber"] = request.LogNumber.ToString(),
                        ["Contains"] = request.ContainsText ?? string.Empty,
                        ["From"] = request.From?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty,
                        ["To"] = request.To?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty,
                        ["Top"] = request.Top?.ToString() ?? string.Empty,
                        ["Severity"] = request.SeverityFilter?.ToString() ?? string.Empty,
                        ["Category"] = request.CategoryFilter?.ToString() ?? string.Empty
                    }
                });

            AnsiConsole.MarkupLine($"[green]Raport zapisany do:[/] {Markup.Escape(outValue)}");
            return 0;
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("LogDate");
        table.AddColumn("Severity");
        table.AddColumn("Category");
        table.AddColumn("ProcessInfo");
        table.AddColumn("Text");

        foreach (var entry in entries)
        {
            table.AddRow(
                Markup.Escape(entry.LogDate.ToString("yyyy-MM-dd HH:mm:ss")),
                Markup.Escape(entry.Severity.ToString()),
                Markup.Escape(entry.Category.ToString()),
                Markup.Escape(entry.ProcessInfo),
                Markup.Escape(Truncate(entry.Text, 120)));
        }

        AnsiConsole.Write(table);
        return 0;
    }

    private static bool TryParseFormat(string? value, out ReportFormat format)
    {
        format = ReportFormat.Markdown;

        if (string.IsNullOrWhiteSpace(value))
        {
            return true;
        }

        if (string.Equals(value, "md", StringComparison.OrdinalIgnoreCase))
        {
            format = ReportFormat.Markdown;
            return true;
        }

        return Enum.TryParse(value, true, out format);
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
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --severity Error[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --category ExtendedEvents[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --from \"2026-03-22 00:00\" --to \"2026-03-22 23:59\"[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --top 50 --format json --out \".\\reports\\errorlog.json\"[/]");
        AnsiConsole.MarkupLine("  [green]errorlog read --name LOCALDEV --category ExtendedEvents --top 20 --format md --out \".\\reports\\errorlog-xe.md\"[/]");
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