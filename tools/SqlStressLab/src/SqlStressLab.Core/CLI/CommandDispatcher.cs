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
    private readonly RenderCommandService _renderCommandService;
    private readonly RunTemplateCommandService _runTemplateCommandService;
    private readonly RunMatrixCommandService _runMatrixCommandService;
    private readonly BatchCommandService _batchCommandService;
    private readonly RunbookCommandService _runbookCommandService;
    private readonly BundleCommandService _bundleCommandService;
    private readonly PublishBundleCommandService _publishBundleCommandService;

    public CommandDispatcher(
        RunCommandService runCommandService,
        CompareCommandService compareCommandService,
        TrendCommandService trendCommandService,
        ListRunsCommandService listRunsCommandService,
        DiagnosticsCommandService diagnosticsCommandService,
        SelfCheckCommandService selfCheckCommandService,
        ListEnvironmentsCommandService listEnvironmentsCommandService,
        ListScenarioPacksCommandService listScenarioPacksCommandService,
        RenderCommandService renderCommandService,
        RunTemplateCommandService runTemplateCommandService,
        RunMatrixCommandService runMatrixCommandService,
        BatchCommandService batchCommandService,
        RunbookCommandService runbookCommandService,
        BundleCommandService bundleCommandService,
        PublishBundleCommandService publishBundleCommandService)
    {
        _runCommandService = runCommandService;
        _compareCommandService = compareCommandService;
        _trendCommandService = trendCommandService;
        _listRunsCommandService = listRunsCommandService;
        _diagnosticsCommandService = diagnosticsCommandService;
        _selfCheckCommandService = selfCheckCommandService;
        _listEnvironmentsCommandService = listEnvironmentsCommandService;
        _listScenarioPacksCommandService = listScenarioPacksCommandService;
        _renderCommandService = renderCommandService;
        _runTemplateCommandService = runTemplateCommandService;
        _runMatrixCommandService = runMatrixCommandService;
        _batchCommandService = batchCommandService;
        _runbookCommandService = runbookCommandService;
        _bundleCommandService = bundleCommandService;
        _publishBundleCommandService = publishBundleCommandService;
    }

    public async Task<int> DispatchAsync(CliArguments args, CancellationToken cancellationToken = default)
    {
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
            CommandNames.Render => await _renderCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.RunTemplate => await _runTemplateCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.RunMatrix => await _runMatrixCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.Batch => await _batchCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.Runbook => await _runbookCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.Bundle => await _bundleCommandService.ExecuteAsync(args, cancellationToken),
            CommandNames.PublishBundle => await _publishBundleCommandService.ExecuteAsync(args, cancellationToken),
            _ => throw new InvalidOperationException($"Nieznana komenda: {args.Command}")
        };
    }
}