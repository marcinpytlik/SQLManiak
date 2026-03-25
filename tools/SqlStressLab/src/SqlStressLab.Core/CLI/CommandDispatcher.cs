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

        var command = (args.Command ?? "run").Trim().ToLowerInvariant();

        return command switch
        {
            "run" => await _runCommandService.ExecuteAsync(args, cancellationToken),
            "compare" => await _compareCommandService.ExecuteAsync(args, cancellationToken),
            "trend" => await _trendCommandService.ExecuteAsync(args, cancellationToken),
            _ => throw new InvalidOperationException($"Nieznana komenda: {args.Command}")
        };
    }
}