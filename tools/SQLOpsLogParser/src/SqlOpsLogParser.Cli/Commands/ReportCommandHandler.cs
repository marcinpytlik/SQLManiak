using Spectre.Console;
using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Cli.Commands;

public sealed class ReportCommandHandler(
    IProfileProvider profileProvider,
    IOperationalReportService operationalReportService,
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
            "nightly" => await HandleNightlyAsync(args),
            "incident" => await HandleIncidentAsync(args),
            _ => HandleUnknownSubcommand()
        };
    }

    private async Task<int> HandleNightlyAsync(string[] args)
    {
        var profile = GetProfile(args);
        if (profile is null)
        {
            return 3;
        }

        var hoursValue = GetOptionValue(args, "--hours");
        var outValue = GetOptionValue(args, "--out");
        var formatValue = GetOptionValue(args, "--format");

        var hours = 24;

        if (!string.IsNullOrWhiteSpace(hoursValue))
        {
            if (!int.TryParse(hoursValue, out hours) || hours <= 0)
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --hours[/]");
                return 4;
            }
        }

        var report = await operationalReportService.BuildNightlyReportAsync(profile, hours);

        if (!string.IsNullOrWhiteSpace(outValue))
        {
            if (!TryParseFormat(formatValue, out var format))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --format[/]");
                return 4;
            }

            await reportService.WriteAsync(
                new[] { report },
                new ReportRequest
                {
                    OutputPath = outValue,
                    Format = format,
                    Title = "Nightly Report",
                    Metadata = new Dictionary<string, string>
                    {
                        ["Profile"] = profile.Name,
                        ["Hours"] = hours.ToString()
                    }
                });

            AnsiConsole.MarkupLine($"[green]Raport zapisany do:[/] {Markup.Escape(outValue)}");
            return 0;
        }

        RenderSummary(report.ProfileName, report.Summary);
        return 0;
    }

    private async Task<int> HandleIncidentAsync(string[] args)
    {
        var profile = GetProfile(args);
        if (profile is null)
        {
            return 3;
        }

        var fromValue = GetOptionValue(args, "--from");
        var toValue = GetOptionValue(args, "--to");
        var hoursValue = GetOptionValue(args, "--hours");
        var containsValue = GetOptionValue(args, "--contains");
        var outValue = GetOptionValue(args, "--out");
        var formatValue = GetOptionValue(args, "--format");

        DateTime? from = null;
        DateTime? to = null;
        int? hours = null;

        if (!string.IsNullOrWhiteSpace(fromValue))
        {
            if (!DateTime.TryParse(fromValue, out var parsedFrom))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --from[/]");
                return 4;
            }

            from = parsedFrom;
        }

        if (!string.IsNullOrWhiteSpace(toValue))
        {
            if (!DateTime.TryParse(toValue, out var parsedTo))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --to[/]");
                return 4;
            }

            to = parsedTo;
        }

        if (from.HasValue && to.HasValue && from > to)
        {
            AnsiConsole.MarkupLine("[red]Parametr --from nie może być większy niż --to[/]");
            return 4;
        }

        if (!string.IsNullOrWhiteSpace(hoursValue))
        {
            if (!int.TryParse(hoursValue, out var parsedHours) || parsedHours <= 0)
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --hours[/]");
                return 4;
            }

            hours = parsedHours;
        }

        if (!from.HasValue && !to.HasValue && !hours.HasValue)
        {
            hours = 24;
        }

        var report = await operationalReportService.BuildIncidentReportAsync(
            profile,
            from,
            to,
            hours,
            containsValue);

        if (!string.IsNullOrWhiteSpace(outValue))
        {
            if (!TryParseFormat(formatValue, out var format))
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --format[/]");
                return 4;
            }

            await reportService.WriteAsync(
                new[] { report },
                new ReportRequest
                {
                    OutputPath = outValue,
                    Format = format,
                    Title = "Incident Report",
                    Metadata = new Dictionary<string, string>
                    {
                        ["Profile"] = profile.Name,
                        ["Hours"] = hours?.ToString() ?? string.Empty,
                        ["From"] = from?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty,
                        ["To"] = to?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty,
                        ["Contains"] = containsValue ?? string.Empty
                    }
                });

            AnsiConsole.MarkupLine($"[green]Raport zapisany do:[/] {Markup.Escape(outValue)}");
            return 0;
        }

        RenderSummary(report.ProfileName, report.Summary);
        return 0;
    }

    private ServerProfile? GetProfile(string[] args)
    {
        var name = GetOptionValue(args, "--name");

        if (string.IsNullOrWhiteSpace(name))
        {
            AnsiConsole.MarkupLine("[red]Brak parametru --name[/]");
            return null;
        }

        var profile = profileProvider.GetByName(name);

        if (profile is null)
        {
            AnsiConsole.MarkupLine($"[red]Nie znaleziono profilu:[/] {name}");
            return null;
        }

        return profile;
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

    private static void RenderSummary(string profileName, ReportSummary summary)
    {
        var grid = new Grid();
        grid.AddColumn();
        grid.AddColumn();

        grid.AddRow("[yellow]Profile[/]", profileName);
        grid.AddRow("[yellow]From[/]", summary.From?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty);
        grid.AddRow("[yellow]To[/]", summary.To?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty);
        grid.AddRow("[yellow]Timeline events[/]", summary.TotalTimelineEvents.ToString());
        grid.AddRow("[yellow]Error events[/]", summary.ErrorEvents.ToString());
        grid.AddRow("[yellow]Critical events[/]", summary.CriticalEvents.ToString());
        grid.AddRow("[yellow]Failed jobs[/]", summary.FailedJobs.ToString());
        grid.AddRow("[yellow]Failed steps[/]", summary.FailedSteps.ToString());

        AnsiConsole.Write(new Panel(grid).Header("Report summary"));
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

    private static int HandleUnknownSubcommand()
    {
        AnsiConsole.MarkupLine("[red]Nieznana subkomenda report[/]");
        ShowHelp();
        return 4;
    }

    private static void ShowHelp()
    {
        AnsiConsole.MarkupLine("[yellow]Dostępne komendy report:[/]");
        AnsiConsole.MarkupLine("  [green]report nightly --name LOCALDEV --hours 24[/]");
        AnsiConsole.MarkupLine("  [green]report nightly --name LOCALDEV --hours 24 --format md --out \".\\reports\\nightly.md\"[/]");
        AnsiConsole.MarkupLine("  [green]report incident --name LOCALDEV --from \"2026-03-26 19:30\" --to \"2026-03-26 20:30\"[/]");
        AnsiConsole.MarkupLine("  [green]report incident --name LOCALDEV --contains \"MaintenancePlan.Subplan_2\" --hours 24 --format json --out \".\\reports\\incident.json\"[/]");
    }
}