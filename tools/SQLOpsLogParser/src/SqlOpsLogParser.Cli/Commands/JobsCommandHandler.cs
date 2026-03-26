using Spectre.Console;
using SqlOpsLogParser.Core.Interfaces;

namespace SqlOpsLogParser.Cli.Commands;

public sealed class JobsCommandHandler(
    IProfileProvider profileProvider,
    IJobRepository jobRepository)
{
    private async Task<int> HandleFailedStepsAsync(string[] args)
{
    var profile = GetProfile(args);
    if (profile is null)
    {
        return 3;
    }

    var hoursValue = GetOptionValue(args, "--hours");
    var jobName = GetOptionValue(args, "--job");
    var hours = 24;

    if (!string.IsNullOrWhiteSpace(hoursValue))
    {
        if (!int.TryParse(hoursValue, out hours) || hours <= 0)
        {
            AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --hours[/]");
            return 4;
        }
    }

    var failedSteps = await jobRepository.GetFailedJobStepsAsync(profile, hours, jobName);

    if (failedSteps.Count == 0)
    {
        AnsiConsole.MarkupLine("[yellow]Brak failed steps w zadanym oknie czasu.[/]");
        return 3;
    }

    var table = new Table().Border(TableBorder.Rounded);
    table.AddColumn("JobName");
    table.AddColumn("StepId");
    table.AddColumn("StepName");
    table.AddColumn("RunDateTime");
    table.AddColumn("Duration");
    table.AddColumn("Severity");
    table.AddColumn("Subsystem");
    table.AddColumn("Message");

    foreach (var item in failedSteps)
    {
        table.AddRow(
            Markup.Escape(item.JobName),
            Markup.Escape(item.StepId.ToString()),
            Markup.Escape(item.StepName),
            Markup.Escape(item.RunDateTime?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty),
            Markup.Escape(FormatDuration(item.RunDurationSeconds)),
            Markup.Escape(item.SqlSeverity.ToString()),
            Markup.Escape(item.Subsystem ?? string.Empty),
            Markup.Escape(Truncate(item.Message, 120)));
    }

    AnsiConsole.Write(table);
    return 0;
}
private async Task<int> HandleStepsAsync(string[] args)
{
    var profile = GetProfile(args);
    if (profile is null)
    {
        return 3;
    }

    var jobName = GetOptionValue(args, "--job");
    if (string.IsNullOrWhiteSpace(jobName))
    {
        AnsiConsole.MarkupLine("[red]Brak parametru --job[/]");
        return 4;
    }

    var steps = await jobRepository.GetJobStepsAsync(profile, jobName);

    if (steps.Count == 0)
    {
        AnsiConsole.MarkupLine("[yellow]Brak kroków dla podanego joba.[/]");
        return 3;
    }

    var table = new Table().Border(TableBorder.Rounded);
    table.AddColumn("StepId");
    table.AddColumn("StepName");
    table.AddColumn("Subsystem");
    table.AddColumn("Database");
    table.AddColumn("OnSuccess");
    table.AddColumn("OnFail");
    table.AddColumn("Command");

    foreach (var step in steps)
    {
        table.AddRow(
            Markup.Escape(step.StepId.ToString()),
            Markup.Escape(step.StepName),
            Markup.Escape(step.Subsystem),
            Markup.Escape(step.DatabaseName),
            Markup.Escape(step.OnSuccessAction.ToString()),
            Markup.Escape(step.OnFailAction.ToString()),
            Markup.Escape(Truncate(step.Command, 80)));
    }

    AnsiConsole.Write(table);
    return 0;
}

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
            "failed" => await HandleFailedAsync(args),
            "history" => await HandleHistoryAsync(args),
            "steps" => await HandleStepsAsync(args),
    "failed-steps" => await HandleFailedStepsAsync(args),
            _ => HandleUnknownSubcommand()
        };
    }

    private async Task<int> HandleListAsync(string[] args)
    {
        var profile = GetProfile(args);
        if (profile is null)
        {
            return 3;
        }

        var jobs = await jobRepository.GetJobsAsync(profile);

        if (jobs.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak jobów.[/]");
            return 3;
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("Name");
        table.AddColumn("Enabled");
        table.AddColumn("Owner");
        table.AddColumn("Description");

        foreach (var job in jobs)
        {
            table.AddRow(
                Markup.Escape(job.Name),
                job.Enabled ? "[green]Yes[/]" : "[red]No[/]",
                Markup.Escape(job.OwnerLoginName),
                Markup.Escape(Truncate(job.Description, 80)));
        }

        AnsiConsole.Write(table);
        return 0;
    }

    private async Task<int> HandleFailedAsync(string[] args)
    {
        var profile = GetProfile(args);
        if (profile is null)
        {
            return 3;
        }

        var hoursValue = GetOptionValue(args, "--hours");
        var hours = 24;

        if (!string.IsNullOrWhiteSpace(hoursValue))
        {
            if (!int.TryParse(hoursValue, out hours) || hours <= 0)
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --hours[/]");
                return 4;
            }
        }

        var jobs = await jobRepository.GetFailedJobsAsync(profile, hours);

        if (jobs.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak failed jobs w zadanym oknie czasu.[/]");
            return 3;
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("JobName");
        table.AddColumn("RunDateTime");
        table.AddColumn("Duration");
        table.AddColumn("Status");
        table.AddColumn("Severity");
        table.AddColumn("Message");

        foreach (var job in jobs)
        {
            table.AddRow(
                Markup.Escape(job.JobName),
                Markup.Escape(job.RunDateTime?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty),
                Markup.Escape(FormatDuration(job.RunDurationSeconds)),
                "[red]Failed[/]",
                Markup.Escape(job.SqlSeverity.ToString()),
                Markup.Escape(Truncate(job.Message, 100)));
        }

        AnsiConsole.Write(table);
        return 0;
    }

    private async Task<int> HandleHistoryAsync(string[] args)
    {
        var profile = GetProfile(args);
        if (profile is null)
        {
            return 3;
        }

        var jobName = GetOptionValue(args, "--job");
        if (string.IsNullOrWhiteSpace(jobName))
        {
            AnsiConsole.MarkupLine("[red]Brak parametru --job[/]");
            return 4;
        }

        var topValue = GetOptionValue(args, "--top");
        int? top = null;

        if (!string.IsNullOrWhiteSpace(topValue))
        {
            if (!int.TryParse(topValue, out var parsedTop) || parsedTop <= 0)
            {
                AnsiConsole.MarkupLine("[red]Nieprawidłowa wartość parametru --top[/]");
                return 4;
            }

            top = parsedTop;
        }

        var history = await jobRepository.GetJobHistoryAsync(profile, jobName, top);

        if (history.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak historii dla podanego joba.[/]");
            return 3;
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("JobName");
        table.AddColumn("RunDateTime");
        table.AddColumn("Duration");
        table.AddColumn("Status");
        table.AddColumn("SqlMessageId");
        table.AddColumn("Message");

        foreach (var item in history)
        {
            table.AddRow(
                Markup.Escape(item.JobName),
                Markup.Escape(item.RunDateTime?.ToString("yyyy-MM-dd HH:mm:ss") ?? string.Empty),
                Markup.Escape(FormatDuration(item.RunDurationSeconds)),
                Markup.Escape(item.Status.ToString()),
                Markup.Escape(item.SqlMessageId.ToString()),
                Markup.Escape(Truncate(item.Message, 100)));
        }

        AnsiConsole.Write(table);
        return 0;
    }

    private SqlOpsLogParser.Core.Models.ServerProfile? GetProfile(string[] args)
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

    private static string FormatDuration(int seconds)
    {
        var ts = TimeSpan.FromSeconds(seconds);
        return ts.ToString(@"hh\:mm\:ss");
    }

    private static int HandleUnknownSubcommand()
    {
        AnsiConsole.MarkupLine("[red]Nieznana subkomenda jobs[/]");
        ShowHelp();
        return 4;
    }

    private static void ShowHelp()
    {
        AnsiConsole.MarkupLine("[yellow]Dostępne komendy jobs:[/]");
        AnsiConsole.MarkupLine("  [green]jobs list --name LOCALDEV[/]");
        AnsiConsole.MarkupLine("  [green]jobs failed --name LOCALDEV --hours 24[/]");
        AnsiConsole.MarkupLine("  [green]jobs history --name LOCALDEV --job \"Backup User Databases\"[/]");
        AnsiConsole.MarkupLine("  [green]jobs history --name LOCALDEV --job \"Backup User Databases\" --top 20[/]");
    }
}