using System.Text;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class MarkdownReportWriter
{
    public static async Task WriteAsync(
        string filePath,
        StressRunRecord run,
        List<ExecutionSample> samples,
        MarkdownReportOptions options,
        CancellationToken cancellationToken = default)
    {
        var sb = new StringBuilder();

        sb.AppendLine($"# SqlStressLab Report — {run.RunId}");
        sb.AppendLine();
        sb.AppendLine("## Run");
        sb.AppendLine();
        sb.AppendLine($"- Profile: `{run.ProfileName}`");
        sb.AppendLine($"- Scenario: `{run.ScenarioName}`");
        sb.AppendLine($"- Tags: `{run.TagsCsv}`");
        sb.AppendLine($"- Environment: `{run.EnvironmentName}`");
        sb.AppendLine($"- Machine: `{run.MachineName}`");
        sb.AppendLine($"- Server: `{run.ServerName}`");
        sb.AppendLine($"- Database: `{run.DatabaseName}`");
        sb.AppendLine($"- StartedAtUtc: `{run.StartedAtUtc:O}`");
        sb.AppendLine($"- FinishedAtUtc: `{run.FinishedAtUtc:O}`");
        sb.AppendLine($"- WallClockMs: `{run.WallClockMs}`");
        sb.AppendLine();

        sb.AppendLine("## Summary");
        sb.AppendLine();
        sb.AppendLine($"- Workers: `{run.Workers}`");
        sb.AppendLine($"- IterationsPerWorker: `{run.IterationsPerWorker}`");
        sb.AppendLine($"- TotalExecutions: `{run.TotalExecutions}`");
        sb.AppendLine($"- SuccessCount: `{run.SuccessCount}`");
        sb.AppendLine($"- ErrorCount: `{run.ErrorCount}`");
        sb.AppendLine($"- RetryCount: `{run.RetryCount}`");
        sb.AppendLine($"- AvgDurationMs: `{run.AvgDurationMs:F2}`");
        sb.AppendLine($"- P95DurationMs: `{run.P95DurationMs}`");
        sb.AppendLine($"- P99DurationMs: `{run.P99DurationMs}`");
        sb.AppendLine($"- ThroughputPerSecond: `{run.ThroughputPerSecond:F2}`");
        sb.AppendLine();

        if (options.IncludeErrorSummary)
        {
            var errorGroups = samples
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

            sb.AppendLine("## Errors");
            sb.AppendLine();

            if (errorGroups.Count == 0)
            {
                sb.AppendLine("Brak błędów.");
            }
            else
            {
                sb.AppendLine("| Category | SqlErrorNumber | Count |");
                sb.AppendLine("|---|---:|---:|");

                foreach (var e in errorGroups)
                {
                    sb.AppendLine($"| {e.ErrorCategory} | {e.SqlErrorNumber} | {e.Count} |");
                }
            }

            sb.AppendLine();
        }

        if (options.IncludeTopSlowestSamples)
        {
            var slowest = samples
                .OrderByDescending(x => x.DurationMs)
                .Take(options.TopSlowestSamplesCount)
                .ToList();

            sb.AppendLine("## Top slowest samples");
            sb.AppendLine();
            sb.AppendLine("| WorkerId | Iteration | DurationMs | Success | RetryAttempt | Spid | ErrorCategory |");
            sb.AppendLine("|---:|---:|---:|---|---:|---:|---|");

            foreach (var s in slowest)
            {
                sb.AppendLine($"| {s.WorkerId} | {s.Iteration} | {s.DurationMs} | {s.Success} | {s.RetryAttempt} | {s.Spid} | {s.ErrorCategory} |");
            }

            sb.AppendLine();
        }

        Directory.CreateDirectory(Path.GetDirectoryName(filePath)!);
        await File.WriteAllTextAsync(filePath, sb.ToString(), cancellationToken);
    }
}