using Spectre.Console;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Cli.Commands;

public sealed class ProfilesCommandHandler(
    IProfileProvider profileProvider,
    IConnectionTestService connectionTestService)
{
    public async Task<int> HandleAsync(string[] args)
    {
        if (args.Length < 2)
        {
            ShowProfilesHelp();
            return 4;
        }

        var subcommand = args[1].ToLowerInvariant();

        return subcommand switch
        {
            "list" => await HandleListAsync(),
            "show" => await HandleShowAsync(args),
            "test" => await HandleTestAsync(args),
            _ => HandleUnknownSubcommand()
        };
    }

    private Task<int> HandleListAsync()
    {
        var profiles = profileProvider.GetAll();

        if (profiles.Count == 0)
        {
            AnsiConsole.MarkupLine("[yellow]Brak profili w profiles.json[/]");
            return Task.FromResult(3);
        }

        var table = new Table().Border(TableBorder.Rounded);
        table.AddColumn("Name");
        table.AddColumn("Server");
        table.AddColumn("Database");
        table.AddColumn("Auth");
        table.AddColumn("Encrypt");
        table.AddColumn("TrustCert");

        foreach (var profile in profiles)
        {
            table.AddRow(
                profile.Name,
                profile.Server,
                profile.Database,
                profile.Authentication,
                profile.Encrypt ? "Yes" : "No",
                profile.TrustServerCertificate ? "Yes" : "No");
        }

        AnsiConsole.Write(table);
        return Task.FromResult(0);
    }

    private Task<int> HandleShowAsync(string[] args)
    {
        var name = GetOptionValue(args, "--name");

        if (string.IsNullOrWhiteSpace(name))
        {
            AnsiConsole.MarkupLine("[red]Brak parametru --name[/]");
            return Task.FromResult(4);
        }

        var profile = profileProvider.GetByName(name);

        if (profile is null)
        {
            AnsiConsole.MarkupLine($"[red]Nie znaleziono profilu:[/] {name}");
            return Task.FromResult(3);
        }

        var grid = new Grid();
        grid.AddColumn();
        grid.AddColumn();

        grid.AddRow("[yellow]Name[/]", profile.Name);
        grid.AddRow("[yellow]Server[/]", profile.Server);
        grid.AddRow("[yellow]Database[/]", profile.Database);
        grid.AddRow("[yellow]Authentication[/]", profile.Authentication);
        grid.AddRow("[yellow]Encrypt[/]", profile.Encrypt.ToString());
        grid.AddRow("[yellow]TrustServerCertificate[/]", profile.TrustServerCertificate.ToString());
        grid.AddRow("[yellow]ConnectTimeoutSeconds[/]", profile.ConnectTimeoutSeconds.ToString());

        AnsiConsole.Write(new Panel(grid).Header("Profile details"));
        return Task.FromResult(0);
    }

    private async Task<int> HandleTestAsync(string[] args)
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

        AnsiConsole.MarkupLine($"[yellow]Testuję połączenie dla profilu:[/] {profile.Name}");

        var result = await connectionTestService.TestAsync(profile);

        if (result.Success)
        {
            var grid = new Grid();
            grid.AddColumn();
            grid.AddColumn();

            grid.AddRow("[green]Success[/]", "True");
            grid.AddRow("[green]ServerName[/]", result.ServerName);
            grid.AddRow("[green]ProductVersion[/]", result.ProductVersion ?? string.Empty);
            grid.AddRow("[green]Edition[/]", result.Edition ?? string.Empty);
            grid.AddRow("[green]Duration[/]", result.Duration.ToString());

            AnsiConsole.Write(new Panel(grid).Header("Connection test"));
            return 0;
        }

        AnsiConsole.MarkupLine($"[red]Connection failed:[/] {result.ErrorMessage}");
        return 2;
    }

    private static int HandleUnknownSubcommand()
    {
        AnsiConsole.MarkupLine("[red]Nieznana subkomenda profiles[/]");
        ShowProfilesHelp();
        return 4;
    }

    private static void ShowProfilesHelp()
    {
        AnsiConsole.MarkupLine("[yellow]Dostępne komendy:[/]");
        AnsiConsole.MarkupLine("  [green]profiles list[/]");
        AnsiConsole.MarkupLine("  [green]profiles show --name LOCALDEV[/]");
        AnsiConsole.MarkupLine("  [green]profiles test --name LOCALDEV[/]");
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