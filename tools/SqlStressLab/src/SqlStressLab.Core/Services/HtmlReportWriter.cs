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
        TrendAnalysisResult? trendResult,
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

        sb.AppendLine("<div class=\"card\">");
        sb.AppendLine("<h2>Run</h2>");
        sb.AppendLine("<table>");
        AppendRow(sb, "RunId", run.RunId);
        AppendRow(sb, "Profile", run.ProfileName);
        AppendRow(sb, "Scenario", run.ScenarioName);
        AppendRow(sb, "Environment", run.EnvironmentName);
        AppendRow(sb, "Tags", run.TagsCsv);
        AppendRow(sb, "Server", run.ServerName);
        AppendRow(sb, "Database", run.DatabaseName);
        AppendRow(sb, "CommandType", run.CommandType);
        AppendRow(sb, "ExecutionMode", run.ExecutionMode);
        AppendRow(sb, "Workers", run.Workers.ToString());
        AppendRow(sb, "IterationsPerWorker", run.IterationsPerWorker.ToString());
        AppendRow(sb, "StartedAtUtc", run.StartedAtUtc.ToString("O"));
        AppendRow(sb, "FinishedAtUtc", run.FinishedAtUtc.ToString("O"));
        AppendRow(sb, "WallClockMs", run.WallClockMs.ToString());
        sb.AppendLine("</table>");
        sb.AppendLine("</div>");

        sb.AppendLine("<div class=\"card\">");
        sb.AppendLine("<h2>Summary</h2>");
        sb.AppendLine("<table>");
        AppendRow(sb, "TotalExecutions", run.TotalExecutions.ToString());
        AppendRow(sb, "SuccessCount", run.SuccessCount.ToString());
        AppendRow(sb, "ErrorCount", run.ErrorCount.ToString());
        AppendRow(sb, "RetryCount", run.RetryCount.ToString());
        AppendRow(sb, "AvgDurationMs", run.AvgDurationMs.ToString("F2"));
        AppendRow(sb, "MinDurationMs", run.MinDurationMs.ToString());
        AppendRow(sb, "P50DurationMs", run.P50DurationMs.ToString());
        AppendRow(sb, "P95DurationMs", run.P95DurationMs.ToString());
        AppendRow(sb, "P99DurationMs", run.P99DurationMs.ToString());
        AppendRow(sb, "MaxDurationMs", run.MaxDurationMs.ToString());
        AppendRow(sb, "ThroughputPerSecond", run.ThroughputPerSecond.ToString("F2"));
        sb.AppendLine("</table>");
        sb.AppendLine("</div>");

        if (comparisonResult is not null)
        {
            sb.AppendLine("<div class=\"card\">");
            sb.AppendLine("<h2>Comparison</h2>");
            sb.AppendLine("<table>");
            AppendRow(sb, "BaselineRunId", comparisonResult.BaselineRunId);
            AppendRow(sb, "CurrentProfile", comparisonResult.CurrentProfileName);
            AppendRow(sb, "BaselineProfile", comparisonResult.BaselineProfileName);
            AppendRow(sb, "CurrentScenario", comparisonResult.CurrentScenarioName);
            AppendRow(sb, "BaselineScenario", comparisonResult.BaselineScenarioName);
            AppendRow(sb, "AvgDurationDeltaMs", comparisonResult.AvgDurationDeltaMs.ToString("F2"));
            AppendRow(sb, "P95DurationDeltaMs", comparisonResult.P95DurationDeltaMs.ToString());
            AppendRow(sb, "ThroughputDelta", comparisonResult.ThroughputDelta.ToString("F2"));
            AppendRow(sb, "ErrorCountDelta", comparisonResult.ErrorCountDelta.ToString());
            AppendRow(sb, "RetryCountDelta", comparisonResult.RetryCountDelta.ToString());
            AppendRow(sb, "IsRegression", comparisonResult.IsRegression.ToString());
            AppendRow(sb, "ComparedAtUtc", comparisonResult.ComparedAtUtc.ToString("O"));
            sb.AppendLine("</table>");
            sb.AppendLine("<p><strong>Summary:</strong> " + Html(comparisonResult.SummaryText) + "</p>");
            sb.AppendLine("</div>");
        }

        if (trendResult is not null)
        {
            sb.AppendLine("<div class=\"card\">");
            sb.AppendLine("<h2>Trend</h2>");
            sb.AppendLine("<table>");
            AppendRow(sb, "ProfileName", trendResult.ProfileName);
            AppendRow(sb, "RequestedTop", trendResult.RequestedTop.ToString());
            AppendRow(sb, "AvgDurationTrendDirection", trendResult.AvgDurationTrendDirection);
            AppendRow(sb, "P95DurationTrendDirection", trendResult.P95DurationTrendDirection);
            AppendRow(sb, "ThroughputTrendDirection", trendResult.ThroughputTrendDirection);
            AppendRow(sb, "ErrorTrendDirection", trendResult.ErrorTrendDirection);
            AppendRow(sb, "SummaryVerdict", trendResult.SummaryVerdict);
            sb.AppendLine("</table>");

            if (trendResult.Points.Count > 0)
            {
                sb.AppendLine("<h3>Trend Points</h3>");
                sb.AppendLine("<table>");
                sb.AppendLine("<tr><th>RunId</th><th>StartedAtUtc</th><th>AvgDurationMs</th><th>P95DurationMs</th><th>ThroughputPerSecond</th><th>ErrorCount</th></tr>");

                foreach (var point in trendResult.Points)
                {
                    sb.AppendLine("<tr>");
                    sb.AppendLine($"<td>{Html(point.RunId)}</td>");
                    sb.AppendLine($"<td>{Html(point.StartedAtUtc.ToString("O"))}</td>");
                    sb.AppendLine($"<td>{point.AvgDurationMs:F2}</td>");
                    sb.AppendLine($"<td>{point.P95DurationMs}</td>");
                    sb.AppendLine($"<td>{point.ThroughputPerSecond:F2}</td>");
                    sb.AppendLine($"<td>{point.ErrorCount}</td>");
                    sb.AppendLine("</tr>");
                }

                sb.AppendLine("</table>");
            }

            sb.AppendLine("</div>");
        }

        sb.AppendLine("<div class=\"card\">");
        sb.AppendLine("<h2>SQL Server Environment</h2>");
        sb.AppendLine("<table>");
        AppendRow(sb, "ProductVersion", sqlEnvironment.ProductVersion);
        AppendRow(sb, "ProductLevel", sqlEnvironment.ProductLevel);
        AppendRow(sb, "Edition", sqlEnvironment.Edition);
        AppendRow(sb, "EngineEdition", sqlEnvironment.EngineEdition);
        AppendRow(sb, "InstanceName", sqlEnvironment.InstanceName);
        AppendRow(sb, "CompatibilityLevel", sqlEnvironment.CompatibilityLevel.ToString());
        sb.AppendLine("</table>");
        sb.AppendLine("</div>");

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

        if (options.IncludeSlowSamples)
        {
            sb.AppendLine("<div class=\"card\">");
            sb.AppendLine($"<h2>Top {Math.Max(1, options.TopSlowSamplesCount)} Slow Samples</h2>");
            sb.AppendLine("<table>");
            sb.AppendLine("<tr><th>WorkerId</th><th>Iteration</th><th>DurationMs</th><th>Success</th><th>RetryAttempt</th><th>ErrorCategory</th><th>SqlErrorNumber</th></tr>");

            foreach (var sample in slowSamples)
            {
                sb.AppendLine("<tr>");
                sb.AppendLine($"<td>{sample.WorkerId}</td>");
                sb.AppendLine($"<td>{sample.Iteration}</td>");
                sb.AppendLine($"<td>{sample.DurationMs}</td>");
                sb.AppendLine($"<td>{sample.Success}</td>");
                sb.AppendLine($"<td>{sample.RetryAttempt}</td>");
                sb.AppendLine($"<td>{Html(sample.ErrorCategory ?? "")}</td>");
                sb.AppendLine($"<td>{Html(sample.SqlErrorNumber?.ToString() ?? "")}</td>");
                sb.AppendLine("</tr>");
            }

            sb.AppendLine("</table>");
            sb.AppendLine("</div>");
        }

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

    private static void AppendRow(StringBuilder sb, string name, string value)
    {
        sb.AppendLine("<tr><th>" + Html(name) + "</th><td>" + Html(value) + "</td></tr>");
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