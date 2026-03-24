using System.Text;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class MarkdownReportWriter
{
    public static async Task WriteAsync(
        string outputPath,
        StressRunRecord run,
        List<ExecutionSample> samples,
        MarkdownReportOptions options,
        RunComparisonResult? comparisonResult,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(outputPath);
        ArgumentNullException.ThrowIfNull(run);
        ArgumentNullException.ThrowIfNull(samples);
        ArgumentNullException.ThrowIfNull(options);

        var directory = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        var sb = new StringBuilder();

        sb.AppendLine($"# SqlStressLab Report — {run.RunId}");
        sb.AppendLine();

        sb.AppendLine("## Run");
        sb.AppendLine();
        sb.AppendLine($"- **RunId:** `{run.RunId}`");
        sb.AppendLine($"- **Profile:** `{run.ProfileName}`");
        sb.AppendLine($"- **Scenario:** `{run.ScenarioName}`");
        sb.AppendLine($"- **Environment:** `{run.EnvironmentName}`");
        sb.AppendLine($"- **Tags:** `{run.TagsCsv}`");
        sb.AppendLine($"- **StartedAtUtc:** `{run.StartedAtUtc:O}`");
        sb.AppendLine($"- **FinishedAtUtc:** `{run.FinishedAtUtc:O}`");
        sb.AppendLine($"- **WallClockMs:** `{run.WallClockMs}`");
        sb.AppendLine();

        sb.AppendLine("## Target");
        sb.AppendLine();
        sb.AppendLine($"- **Server:** `{run.ServerName}`");
        sb.AppendLine($"- **Database:** `{run.DatabaseName}`");
        sb.AppendLine($"- **CommandType:** `{run.CommandType}`");
        sb.AppendLine($"- **ExecutionMode:** `{run.ExecutionMode}`");
        sb.AppendLine($"- **Workers:** `{run.Workers}`");
        sb.AppendLine($"- **IterationsPerWorker:** `{run.IterationsPerWorker}`");
        sb.AppendLine();

        sb.AppendLine("## Summary");
        sb.AppendLine();
        sb.AppendLine($"- **TotalExecutions:** `{run.TotalExecutions}`");
        sb.AppendLine($"- **SuccessCount:** `{run.SuccessCount}`");
        sb.AppendLine($"- **ErrorCount:** `{run.ErrorCount}`");
        sb.AppendLine($"- **RetryCount:** `{run.RetryCount}`");
        sb.AppendLine($"- **AvgDurationMs:** `{run.AvgDurationMs:F2}`");
        sb.AppendLine($"- **MinDurationMs:** `{run.MinDurationMs}`");
        sb.AppendLine($"- **P50DurationMs:** `{run.P50DurationMs}`");
        sb.AppendLine($"- **P95DurationMs:** `{run.P95DurationMs}`");
        sb.AppendLine($"- **P99DurationMs:** `{run.P99DurationMs}`");
        sb.AppendLine($"- **MaxDurationMs:** `{run.MaxDurationMs}`");
        sb.AppendLine($"- **ThroughputPerSecond:** `{run.ThroughputPerSecond:F2}`");
        sb.AppendLine();

        sb.AppendLine("## Client Environment");
        sb.AppendLine();
        sb.AppendLine($"- **MachineName:** `{run.MachineName}`");
        sb.AppendLine($"- **OsVersion:** `{run.OsVersion}`");
        sb.AppendLine($"- **DotNetVersion:** `{run.DotNetVersion}`");
        sb.AppendLine();

        sb.AppendLine("## SQL Server Environment");
        sb.AppendLine();
        sb.AppendLine($"- **SqlProductVersion:** `{run.SqlProductVersion}`");
        sb.AppendLine($"- **SqlProductLevel:** `{run.SqlProductLevel}`");
        sb.AppendLine($"- **SqlEdition:** `{run.SqlEdition}`");
        sb.AppendLine($"- **SqlEngineEdition:** `{run.SqlEngineEdition}`");
        sb.AppendLine($"- **SqlInstanceName:** `{run.SqlInstanceName}`");
        sb.AppendLine($"- **SqlCompatibilityLevel:** `{run.SqlCompatibilityLevel}`");
        sb.AppendLine();

        if (comparisonResult is not null)
        {
            sb.AppendLine("## Comparison");
            sb.AppendLine();
            sb.AppendLine($"- **BaselineRunId:** `{comparisonResult.BaselineRunId}`");
            sb.AppendLine($"- **CurrentProfile:** `{comparisonResult.CurrentProfileName}`");
            sb.AppendLine($"- **BaselineProfile:** `{comparisonResult.BaselineProfileName}`");
            sb.AppendLine($"- **CurrentScenario:** `{comparisonResult.CurrentScenarioName}`");
            sb.AppendLine($"- **BaselineScenario:** `{comparisonResult.BaselineScenarioName}`");
            sb.AppendLine($"- **AvgDurationDeltaMs:** `{comparisonResult.AvgDurationDeltaMs:F2}`");
            sb.AppendLine($"- **P95DurationDeltaMs:** `{comparisonResult.P95DurationDeltaMs}`");
            sb.AppendLine($"- **ThroughputDelta:** `{comparisonResult.ThroughputDelta:F2}`");
            sb.AppendLine($"- **ErrorCountDelta:** `{comparisonResult.ErrorCountDelta}`");
            sb.AppendLine($"- **RetryCountDelta:** `{comparisonResult.RetryCountDelta}`");
            sb.AppendLine($"- **IsRegression:** `{comparisonResult.IsRegression}`");
            sb.AppendLine($"- **ComparedAtUtc:** `{comparisonResult.ComparedAtUtc:O}`");
            sb.AppendLine();
            sb.AppendLine("> " + comparisonResult.SummaryText);
            sb.AppendLine();
        }

        if (options.IncludeErrorSummary)
        {
            var errors = samples
                .Where(x => !x.Success)
                .GroupBy(x => new { x.ErrorCategory, x.SqlErrorNumber })
                .Select(g => new
                {
                    g.Key.ErrorCategory,
                    g.Key.SqlErrorNumber,
                    Count = g.Count()
                })
                .OrderByDescending(x => x.Count)
                .ToList();

            sb.AppendLine("## Error Summary");
            sb.AppendLine();

            if (errors.Count == 0)
            {
                sb.AppendLine("Brak błędów.");
                sb.AppendLine();
            }
            else
            {
                sb.AppendLine("| ErrorCategory | SqlErrorNumber | Count |");
                sb.AppendLine("|---|---:|---:|");

                foreach (var err in errors)
                {
                    sb.AppendLine($"| {err.ErrorCategory ?? "Unknown"} | {err.SqlErrorNumber?.ToString() ?? ""} | {err.Count} |");
                }

                sb.AppendLine();
            }
        }

        if (options.IncludeTopSlowestSamples)
        {
            var top = Math.Max(1, options.TopSlowestSamplesCount);

            var slowest = samples
                .OrderByDescending(x => x.DurationMs)
                .ThenBy(x => x.WorkerId)
                .ThenBy(x => x.Iteration)
                .Take(top)
                .ToList();

            sb.AppendLine($"## Top {top} Slowest Samples");
            sb.AppendLine();
            sb.AppendLine("| WorkerId | Iteration | DurationMs | Success | RetryAttempt | ErrorCategory | SqlErrorNumber |");
            sb.AppendLine("|---:|---:|---:|---|---:|---|---:|");

            foreach (var sample in slowest)
            {
                sb.AppendLine(
                    $"| {sample.WorkerId} | {sample.Iteration} | {sample.DurationMs} | {sample.Success} | {sample.RetryAttempt} | {sample.ErrorCategory ?? ""} | {sample.SqlErrorNumber?.ToString() ?? ""} |");
            }

            sb.AppendLine();
        }

        await File.WriteAllTextAsync(outputPath, sb.ToString(), cancellationToken);
    }
}