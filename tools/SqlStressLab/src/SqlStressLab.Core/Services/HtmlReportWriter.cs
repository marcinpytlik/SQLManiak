using System.Net;
using System.Text;
using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class HtmlReportWriter
{
    public static async Task WriteAsync(
        string outputPath,
        StressRunRecord run,
        SqlServerEnvironmentInfo sqlEnvironment,
        List<ExecutionSample> samples,
        List<DmvSnapshot> dmvSnapshots,
        HtmlReportOptions options,
        RunComparisonResult? comparisonResult,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(outputPath);
        ArgumentNullException.ThrowIfNull(run);
        ArgumentNullException.ThrowIfNull(sqlEnvironment);
        ArgumentNullException.ThrowIfNull(samples);
        ArgumentNullException.ThrowIfNull(dmvSnapshots);
        ArgumentNullException.ThrowIfNull(options);

        var directory = Path.GetDirectoryName(outputPath);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

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

        var slowSamples = samples
            .OrderByDescending(x => x.DurationMs)
            .ThenBy(x => x.WorkerId)
            .ThenBy(x => x.Iteration)
            .Take(Math.Max(1, options.TopSlowSamplesCount))
            .ToList();

        var sb = new StringBuilder();

        sb.AppendLine("<!DOCTYPE html>");
        sb.AppendLine("<html lang=\"pl\">");
        sb.AppendLine("<head>");
        sb.AppendLine("  <meta charset=\"utf-8\" />");
        sb.AppendLine("  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />");
        sb.AppendLine($"  <title>SqlStressLab Report - {Html(run.RunId)}</title>");
        sb.AppendLine("  <style>");
        sb.AppendLine("    body { font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #222; }");
        sb.AppendLine("    h1, h2, h3 { color: #0f3d66; }");
        sb.AppendLine("    table { border-collapse: collapse; width: 100%; margin-bottom: 24px; }");
        sb.AppendLine("    th, td { border: 1px solid #d0d7de; padding: 8px; text-align: left; vertical-align: top; }");
        sb.AppendLine("    th { background: #f3f6f9; }");
        sb.AppendLine("    .card { border: 1px solid #d0d7de; border-radius: 8px; padding: 16px; margin-bottom: 20px; background: #fff; }");
        sb.AppendLine("    .muted { color: #666; }");
        sb.AppendLine("    .ok { color: #0a7a28; font-weight: 600; }");
        sb.AppendLine("    .warn { color: #b26a00; font-weight: 600; }");
        sb.AppendLine("    .bad { color: #b42318; font-weight: 600; }");
        sb.AppendLine("    code { background: #f6f8fa; padding: 2px 4px; border-radius: 4px; }");
        sb.AppendLine("    pre { background: #f6f8fa; padding: 12px; border-radius: 8px; overflow-x: auto; }");
        sb.AppendLine("  </style>");
        sb.AppendLine("</head>");
        sb.AppendLine("<body>");

        sb.AppendLine($"<h1>SqlStressLab Report - {Html(run.RunId)}</h1>");
        sb.AppendLine($"<p class=\"muted\">Wygenerowano: {Html(DateTime.UtcNow.ToString("O"))}</p>");

        // Run summary
        sb.AppendLine("<div class=\"card\">");
        sb.AppendLine("<h2>Run</h2>");
        sb.AppendLine("<table>");
        sb.AppendLine("<tr><th>RunId</th><td>" + Html(run.RunId) + "</td></tr>");
        sb.AppendLine("<tr><th>Profile</th><td>" + Html(run.ProfileName) + "</td></tr>");
        sb.AppendLine("<tr><th>Scenario</th><td>" + Html(run.ScenarioName) + "</td></tr>");
        sb.AppendLine("<tr><th>Environment</th><td>" + Html(run.EnvironmentName) + "</td></tr>");
        sb.AppendLine("<tr><th>Tags</th><td>" + Html(run.TagsCsv) + "</td></tr>");
        sb.AppendLine("<tr><th>Server</th><td>" + Html(run.ServerName) + "</td></tr>");
        sb.AppendLine("<tr><th>Database</th><td>" + Html(run.DatabaseName) + "</td></tr>");
        sb.AppendLine("<tr><th>CommandType</th><td>" + Html(run.CommandType) + "</td></tr>");
        sb.AppendLine("<tr><th>ExecutionMode</th><td>" + Html(run.ExecutionMode) + "</td></tr>");
        sb.AppendLine("<tr><th>Workers</th><td>" + run.Workers + "</td></tr>");
        sb.AppendLine("<tr><th>IterationsPerWorker</th><td>" + run.IterationsPerWorker + "</td></tr>");
        sb.AppendLine("<tr><th>StartedAtUtc</th><td>" + Html(run.StartedAtUtc.ToString("O")) + "</td></tr>");
        sb.AppendLine("<tr><th>FinishedAtUtc</th><td>" + Html(run.FinishedAtUtc.ToString("O")) + "</td></tr>");
        sb.AppendLine("<tr><th>WallClockMs</th><td>" + run.WallClockMs + "</td></tr>");
        sb.AppendLine("</table>");
        sb.AppendLine("</div>");

        // Metrics
        sb.AppendLine("<div class=\"card\">");
        sb.AppendLine("<h2>Summary</h2>");
        sb.AppendLine("<table>");
        sb.AppendLine("<tr><th>TotalExecutions</th><td>" + run.TotalExecutions + "</td></tr>");
        sb.AppendLine("<tr><th>SuccessCount</th><td class=\"ok\">" + run.SuccessCount + "</td></tr>");
        sb.AppendLine("<tr><th>ErrorCount</th><td class=\"" + (run.ErrorCount > 0 ? "bad" : "ok") + "\">" + run.ErrorCount + "</td></tr>");
        sb.AppendLine("<tr><th>RetryCount</th><td>" + run.RetryCount + "</td></tr>");
        sb.AppendLine("<tr><th>AvgDurationMs</th><td>" + run.AvgDurationMs.ToString("F2") + "</td></tr>");
        sb.AppendLine("<tr><th>MinDurationMs</th><td>" + run.MinDurationMs + "</td></tr>");
        sb.AppendLine("<tr><th>P50DurationMs</th><td>" + run.P50DurationMs + "</td></tr>");
        sb.AppendLine("<tr><th>P95DurationMs</th><td>" + run.P95DurationMs + "</td></tr>");
        sb.AppendLine("<tr><th>P99DurationMs</th><td>" + run.P99DurationMs + "</td></tr>");
        sb.AppendLine("<tr><th>MaxDurationMs</th><td>" + run.MaxDurationMs + "</td></tr>");
        sb.AppendLine("<tr><th>ThroughputPerSecond</th><td>" + run.ThroughputPerSecond.ToString("F2") + "</td></tr>");
        sb.AppendLine("</table>");
        sb.AppendLine("</div>");

        // Comparison
        if (comparisonResult is not null)
        {
            sb.AppendLine("<div class=\"card\">");
            sb.AppendLine("<h2>Comparison</h2>");
            sb.AppendLine("<table>");
            sb.AppendLine("<tr><th>BaselineRunId</th><td>" + Html(comparisonResult.BaselineRunId) + "</td></tr>");
            sb.AppendLine("<tr><th>CurrentProfile</th><td>" + Html(comparisonResult.CurrentProfileName) + "</td></tr>");
            sb.AppendLine("<tr><th>BaselineProfile</th><td>" + Html(comparisonResult.BaselineProfileName) + "</td></tr>");
            sb.AppendLine("<tr><th>CurrentScenario</th><td>" + Html(comparisonResult.CurrentScenarioName) + "</td></tr>");
            sb.AppendLine("<tr><th>BaselineScenario</th><td>" + Html(comparisonResult.BaselineScenarioName) + "</td></tr>");
            sb.AppendLine("<tr><th>AvgDurationDeltaMs</th><td>" + comparisonResult.AvgDurationDeltaMs.ToString("F2") + "</td></tr>");
            sb.AppendLine("<tr><th>P95DurationDeltaMs</th><td>" + comparisonResult.P95DurationDeltaMs + "</td></tr>");
            sb.AppendLine("<tr><th>ThroughputDelta</th><td>" + comparisonResult.ThroughputDelta.ToString("F2") + "</td></tr>");
            sb.AppendLine("<tr><th>ErrorCountDelta</th><td>" + comparisonResult.ErrorCountDelta + "</td></tr>");
            sb.AppendLine("<tr><th>RetryCountDelta</th><td>" + comparisonResult.RetryCountDelta + "</td></tr>");
            sb.AppendLine("<tr><th>IsRegression</th><td class=\"" + (comparisonResult.IsRegression ? "bad" : "ok") + "\">" + comparisonResult.IsRegression + "</td></tr>");
            sb.AppendLine("<tr><th>ComparedAtUtc</th><td>" + Html(comparisonResult.ComparedAtUtc.ToString("O")) + "</td></tr>");
            sb.AppendLine("</table>");
            sb.AppendLine("<p><strong>Summary:</strong> " + Html(comparisonResult.SummaryText) + "</p>");
            sb.AppendLine("</div>");
        }

        // SQL environment
        sb.AppendLine("<div class=\"card\">");
        sb.AppendLine("<h2>SQL Server Environment</h2>");
        sb.AppendLine("<table>");
        sb.AppendLine("<tr><th>ProductVersion</th><td>" + Html(sqlEnvironment.ProductVersion) + "</td></tr>");
        sb.AppendLine("<tr><th>ProductLevel</th><td>" + Html(sqlEnvironment.ProductLevel) + "</td></tr>");
        sb.AppendLine("<tr><th>Edition</th><td>" + Html(sqlEnvironment.Edition) + "</td></tr>");
        sb.AppendLine("<tr><th>EngineEdition</th><td>" + Html(sqlEnvironment.EngineEdition) + "</td></tr>");
        sb.AppendLine("<tr><th>InstanceName</th><td>" + Html(sqlEnvironment.InstanceName) + "</td></tr>");
        sb.AppendLine("<tr><th>CompatibilityLevel</th><td>" + sqlEnvironment.CompatibilityLevel + "</td></tr>");
        sb.AppendLine("</table>");
        sb.AppendLine("</div>");

        // Errors
        sb.AppendLine("<div class=\"card\">");
        sb.AppendLine("<h2>Error Summary</h2>");

        if (errorGroups.Count == 0)
        {
            sb.AppendLine("<p class=\"ok\">Brak błędów.</p>");
        }
        else
        {
            sb.AppendLine("<table>");
            sb.AppendLine("<tr><th>ErrorCategory</th><th>SqlErrorNumber</th><th>Count</th></tr>");

            foreach (var err in errorGroups)
            {
                sb.AppendLine("<tr>");
                sb.AppendLine("<td>" + Html(err.ErrorCategory ?? "Unknown") + "</td>");
                sb.AppendLine("<td>" + Html(err.SqlErrorNumber?.ToString() ?? "") + "</td>");
                sb.AppendLine("<td>" + err.Count + "</td>");
                sb.AppendLine("</tr>");
            }

            sb.AppendLine("</table>");
        }

        sb.AppendLine("</div>");

        // Slow samples
        if (options.IncludeSlowSamples)
        {
            sb.AppendLine("<div class=\"card\">");
            sb.AppendLine($"<h2>Top {Math.Max(1, options.TopSlowSamplesCount)} Slow Samples</h2>");
            sb.AppendLine("<table>");
            sb.AppendLine("<tr><th>WorkerId</th><th>Iteration</th><th>DurationMs</th><th>Success</th><th>RetryAttempt</th><th>ErrorCategory</th><th>SqlErrorNumber</th></tr>");

            foreach (var sample in slowSamples)
            {
                sb.AppendLine("<tr>");
                sb.AppendLine("<td>" + sample.WorkerId + "</td>");
                sb.AppendLine("<td>" + sample.Iteration + "</td>");
                sb.AppendLine("<td>" + sample.DurationMs + "</td>");
                sb.AppendLine("<td>" + sample.Success + "</td>");
                sb.AppendLine("<td>" + sample.RetryAttempt + "</td>");
                sb.AppendLine("<td>" + Html(sample.ErrorCategory ?? "") + "</td>");
                sb.AppendLine("<td>" + Html(sample.SqlErrorNumber?.ToString() ?? "") + "</td>");
                sb.AppendLine("</tr>");
            }

            sb.AppendLine("</table>");
            sb.AppendLine("</div>");
        }

        // DMV
        if (options.IncludeDmvSection)
        {
            sb.AppendLine("<div class=\"card\">");
            sb.AppendLine("<h2>DMV Snapshots</h2>");

            if (dmvSnapshots.Count == 0)
            {
                sb.AppendLine("<p class=\"muted\">Brak snapshotów DMV.</p>");
            }
            else
            {
                foreach (var snapshot in dmvSnapshots)
                {
                    sb.AppendLine("<h3>" + Html(snapshot.SnapshotName) + " (" + Html(snapshot.SnapshotPhase) + ")</h3>");
                    sb.AppendLine("<p class=\"muted\">CollectedAtUtc: " + Html(snapshot.CollectedAtUtc.ToString("O")) + "</p>");
                    sb.AppendLine("<p>Liczba wierszy: <strong>" + snapshot.Rows.Count + "</strong></p>");

                    var previewRows = snapshot.Rows.Take(3).ToList();
                    if (previewRows.Count > 0)
                    {
                        foreach (var row in previewRows)
                        {
                            sb.AppendLine("<pre>" + Html(PrettyJson(row.RowJson)) + "</pre>");
                        }
                    }
                }
            }

            sb.AppendLine("</div>");
        }

        sb.AppendLine("</body>");
        sb.AppendLine("</html>");

        await File.WriteAllTextAsync(outputPath, sb.ToString(), cancellationToken);
    }

    private static string Html(string? value)
    {
        return WebUtility.HtmlEncode(value ?? "");
    }

    private static string PrettyJson(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            return JsonSerializer.Serialize(doc.RootElement, new JsonSerializerOptions
            {
                WriteIndented = true
            });
        }
        catch
        {
            return json;
        }
    }
}