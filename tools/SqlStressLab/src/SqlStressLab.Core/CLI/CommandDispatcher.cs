using SqlStressLab.Core.Models;
using SqlStressLab.Core.Services;

namespace SqlStressLab.Core.CLI;

public sealed class CommandDispatcher
{
    private readonly RunCommandService _runCommandService;
    private readonly CompareCommandService _compareCommandService;
    private readonly TrendCommandService _trendCommandService;

    public CommandDispatcher(
        RunCommandService runCommandService,
        CompareCommandService compareCommandService,
        TrendCommandService trendCommandService)
    {
        _runCommandService = runCommandService ?? throw new ArgumentNullException(nameof(runCommandService));
        _compareCommandService = compareCommandService ?? throw new ArgumentNullException(nameof(compareCommandService));
        _trendCommandService = trendCommandService ?? throw new ArgumentNullException(nameof(trendCommandService));
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

            CommandNames.Batch => NotImplemented(CommandNames.Batch),
            CommandNames.Runbook => NotImplemented(CommandNames.Runbook),
            CommandNames.Bundle => NotImplemented(CommandNames.Bundle),
            CommandNames.PublishBundle => NotImplemented(CommandNames.PublishBundle),
            CommandNames.RunTemplate => NotImplemented(CommandNames.RunTemplate),
            CommandNames.RunMatrix => NotImplemented(CommandNames.RunMatrix),
            CommandNames.Render => NotImplemented(CommandNames.Render),
            CommandNames.Diagnostics => NotImplemented(CommandNames.Diagnostics),
            CommandNames.SelfCheck => NotImplemented(CommandNames.SelfCheck),
            CommandNames.ListRuns => NotImplemented(CommandNames.ListRuns),
            CommandNames.ListEnvironments => NotImplemented(CommandNames.ListEnvironments),
            CommandNames.ListScenarioPacks => NotImplemented(CommandNames.ListScenarioPacks),

            _ => throw new InvalidOperationException($"Nieznana komenda: {args.Command}")
        };
    }

    private static int NotImplemented(string command)
    {
        throw new InvalidOperationException(
            $"Komenda '{command}' jest przewidziana w Sprincie 10, ale serwis wykonawczy nie został jeszcze zaimplementowany.");
    }
}