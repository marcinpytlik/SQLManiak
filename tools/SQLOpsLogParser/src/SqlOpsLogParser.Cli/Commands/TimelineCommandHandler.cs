using Spectre.Console;
using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Cli.Commands;

public sealed class TimelineCommandHandler(
    IProfileProvider profileProvider,
    ITimelineService timelineService,
    IReportService reportService)
{
    public async Task<int> HandleAsync(string[] args)
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

        var request = new TimelineRequest
        {
            Profile = profile
        };

        var hoursValue = GetOptionValue(args, "--hours");
        var fromValue = GetOptionValue(args, "--from");
        var toValue = GetOptionValue(args, "--to");
        var topValue = GetOptionValue(args, "--top");
        var sourceValue = GetOptionValue(args, "--source");
        var containsValue = GetOptionValue(args, "--contains");
        var outValue = GetOptionValue(args, "--out");
        var formatValue = GetOptionValue(args, "--format");

        request.OnlyErrors = args.Any(x =>
            string.Equals(x, "--only-errors", StringComparison.OrdinalIgnoreCase));

        request.ContainsText = containsValue;

        if (!string.IsNullOrWhiteSpace(hoursValue))
        {
            if (!int.TryParse(hoursValue, out var hours) || hours <= 0)
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --hours[/]");
                return 4;
            }

            request.Hours = hours;
        }

        if (!string.IsNullOrWhiteSpace(fromValue))
        {
            if (!DateTime.TryParse(fromValue, out var from))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --from[/]");
                return 4;
            }

            request.From = from;
        }

        if (!string.IsNullOrWhiteSpace(toValue))
        {
            if (!DateTime.TryParse(toValue, out var to))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --to[/]");
                return 4;
            }

            request.To = to;
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

        if (!string.IsNullOrWhiteSpace(sourceValue))
        {
            if (!Enum.TryParse<TimelineSourceType>(sourceValue, true, out var source))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --source[/]");
                return 4;
            }

            request.SourceFilter = source;
        }

        if (!request.Hours.HasValue && !request.From.HasValue && !request.To.HasValue)
        {
            request.Hours = 24;
        }

        var events = await timelineService.GetTimelineAsync(request);

        if (events.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak zdarzeń dla podanych filtrów.[/]");
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
                events,
                new ReportRequest
                {
                    OutputPath = outValue,
                    Format = format,
                    Title = "Timeline Report",
                    Metadata = new Dictionary<string, string>
                    {
                        ["Profile"] = profile.Name,
                        ["Hours"] = request.Hours?.ToString() ?? string.Empty,
                        ["From"] = request.From?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty,
                        ["To"] = request.To?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty,
                        ["OnlyErrors"] = request.OnlyErrors.ToString(),
                        ["SourceFilter"] = request.SourceFilter?.ToString() ?? string.Empty,
                        ["Contains"] = request.ContainsText ?? string.Empty,
                        ["Top"] = request.Top?.ToString() ?? string.Empty
                    }
                });

            AnsiConsole.MarkupLine($"[green]Raport zapisany do:[/] {Markup.Escape(outValue)}");
            return 0;
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("EventTime");
        table.AddColumn("Source");
        table.AddColumn("Severity");
        table.AddColumn("Category");
        table.AddColumn("Title");
        table.AddColumn("Message");

        foreach (var item in events)
        {
            table.AddRow(
                Markup.Escape(item.EventTime.ToString("yyyy-MM-dd HH:mm:ss")),
                Markup.Escape(item.Source.ToString()),
                Markup.Escape(item.Severity.ToString()),
                Markup.Escape(item.Category.ToString()),
                Markup.Escape(Truncate(item.Title, 50)),
                Markup.Escape(Truncate(item.Message, 100)));
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

    private static string Truncate(string value, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(value) || value.Length <= maxLength)
        {
            return value;
        }

        return value[..maxLength] + "...";
    }
}