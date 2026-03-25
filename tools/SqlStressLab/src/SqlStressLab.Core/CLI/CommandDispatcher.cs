using SqlStressLab.Core.Models;
using SqlStressLab.Core.Services;

namespace SqlStressLab.Core.CLI;

public sealed class CommandDispatcher
{
    private readonly RunCommandService _runCommandService;
    private readonly CompareCommandService _compareCommandService;
    private readonly TrendCommandService _trendCommandService;
    private readonly ListRunsCommandService _listRunsCommandService;
    private readonly DiagnosticsCommandService _diagnosticsCommandService;
    private readonly SelfCheckCommandService _selfCheckCommandService;
    private readonly ListEnvironmentsCommandService _listEnvironmentsCommandService;
    private readonly ListScenarioPacksCommandService _listScenarioPacksCommandService;

    public CommandDispatcher(
        RunCommandService runCommandService,
        CompareCommandService compareCommandService,
        TrendCommandService trendCommandService,
        ListRunsCommandService listRunsCommandService,
        DiagnosticsCommandService diagnosticsCommandService,
        SelfCheckCommandService selfCheckCommandService,
        ListEnvironmentsCommandService listEnvironmentsCommandService,
        ListScenarioPacksCommandService listScenarioPacksCommandService)
    {
        _runCommandService = runCommandService ?? throw new ArgumentNullException(nameof(runCommandService));
        _compareCommandService = compareCommandService ?? throw new ArgumentNullException(nameof(compareCommandService));
        _trendCommandService = trendCommandService ?? throw new ArgumentNullException(nameof(trendCommandService));
        _listRunsCommandService = listRunsCommandService ?? throw new ArgumentNullException(nameof(listRunsCommandService));
        _diagnosticsCommandService = diagnosticsCommandService ?? throw new ArgumentNullException(nameof(diagnosticsCommandService));
        _selfCheckCommandService = selfCheckCommandService ?? throw new ArgumentNullException(nameof(selfCheckCommandService));
        _listEnvironmentsCommandService = listEnvironmentsCommandService ?? throw new ArgumentNullException(nameof(listEnvironmentsCommandService));
        _listScenarioPacksCommandService = listScenarioPacksCommandService ?? throw new ArgumentNullException(nameof(listScenarioPacksCommandService));
    }

    public async Task<int> DispatchAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        var command = (args.Command ?? CommandNames.Run).Trim().ToLowerInvariant();

        return command switch
        {
            CommandNames.Run => await _runCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.Compare => await _compareCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.Trend => await _trendCommandService.ExecuteAsync(args, cancellationToken),

            CommandNames.ListRuns => await _listRunsCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.Diagnostics => await _diagnosticsCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.SelfCheck => await _selfCheckCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.ListEnvironments => await _listEnvironmentsCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.ListScenarioPacks => await _listScenarioPacksCommandService.ExecuteAsync(args, cancellationToken),

            CommandNames.Batch => NotImplemented(CommandNames.Batch),
            CommandNames.Runbook => NotImplemented(CommandNames.Runbook),
            CommandNames.Bundle => NotImplemented(CommandNames.Bundle),
            CommandNames.PublishBundle => NotImplemented(CommandNames.PublishBundle),
            CommandNames.RunTemplate => NotImplemented(CommandNames.RunTemplate),
            CommandNames.RunMatrix => NotImplemented(CommandNames.RunMatrix),
            CommandNames.Render => NotImplemented(CommandNames.Render),

            _ => throw new InvalidOperationException($"Nieznana komenda: {args.Command}")
        };
    }

    private static int NotImplemented(string command)
    {
        throw new InvalidOperationException(
            $"Komenda '{command}' jest przewidziana w Sprincie 10, ale serwis wykonawczy nie został jeszcze zaimplementowany.");
    }
}