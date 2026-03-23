using System.Text;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class HtmlReportWriter
{
    public static async Task WriteAsync(
        string filePath,
        StressRunRecord run,
        SqlServerEnvironmentInfo sqlEnv,
        List<ExecutionSample> samples,
        List<DmvSnapshot>? dmvSnapshots,
        HtmlReportOptions options,
        CancellationToken cancellationToken = default)
    {
        var slowest = samples
            .OrderByDescending(x => x.DurationMs)
            .Take(options.TopSlowSamplesCount)
            .ToList();

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

        var sb = new StringBuilder();

        sb.AppendLine("<!doctype html>");
        sb.AppendLine("<html><head><meta charset='utf-8'>");
        sb.AppendLine("<title>SqlStressLab Report</title>");
        sb.AppendLine("<style>");
        sb.AppendLine("body{font-family:Segoe UI,Arial,sans-serif;margin:24px;}");
        sb.AppendLine("table{border-collapse:collapse;width:100%;margin-bottom:24px;}");
        sb.AppendLine("th,td{border:1px solid #ccc;padding:8px;text-align:left;}");
        sb.AppendLine("th{background:#f3f3f3;}");
        sb.AppendLine("h1,h2{margin-top:32px;}");
        sb.AppendLine(".ok{color:green;font-weight:bold;}");
        sb.AppendLine(".err{color:#b00020;font-weight:bold;}");
        sb.AppendLine("</style></head><body>");

        sb.AppendLine($"<h1>SqlStressLab Report — {run.RunId}</h1>");

        sb.AppendLine("<h2>Run</h2>");
        sb.AppendLine("<table>");
        sb.AppendLine("<tr><th>Profile</th><td>" + run.ProfileName + "</td></tr>");
        sb.AppendLine("<tr><th>Scenario</th><td>" + run.ScenarioName + "</td></tr>");
        sb.AppendLine("<tr><th>Tags</th><td>" + run.TagsCsv + "</td></tr>");
        sb.AppendLine("<tr><th>Environment</th><td>" + run.EnvironmentName + "</td></tr>");
        sb.AppendLine("<tr><th>Server</th><td>" + run.ServerName + "</td></tr>");
        sb.AppendLine("<tr><th>Database</th><td>" + run.DatabaseName + "</td></tr>");
        sb.AppendLine("<tr><th>StartedAtUtc</th><td>" + run.StartedAtUtc.ToString("O") + "</td></tr>");
        sb.AppendLine("<tr><th>FinishedAtUtc</th><td>" + run.FinishedAtUtc.ToString("O") + "</td></tr>");
        sb.AppendLine("</table>");

        sb.AppendLine("<h2>Summary</h2>");
        sb.AppendLine("<table>");
        sb.AppendLine($"<tr><th>TotalExecutions</th><td>{run.TotalExecutions}</td></tr>");
        sb.AppendLine($"<tr><th>SuccessCount</th><td class='ok'>{run.SuccessCount}</td></tr>");
        sb.AppendLine($"<tr><th>ErrorCount</th><td class='err'>{run.ErrorCount}</td></tr>");
        sb.AppendLine($"<tr><th>RetryCount</th><td>{run.RetryCount}</td></tr>");
        sb.AppendLine($"<tr><th>AvgDurationMs</th><td>{run.AvgDurationMs:F2}</td></tr>");
        sb.AppendLine($"<tr><th>P95DurationMs</th><td>{run.P95DurationMs}</td></tr>");
        sb.AppendLine($"<tr><th>P99DurationMs</th><td>{run.P99DurationMs}</td></tr>");
        sb.AppendLine($"<tr><th>ThroughputPerSecond</th><td>{run.ThroughputPerSecond:F2}</td></tr>");
        sb.AppendLine("</table>");

        sb.AppendLine("<h2>SQL Server environment</h2>");
        sb.AppendLine("<table>");
        sb.AppendLine($"<tr><th>ProductVersion</th><td>{sqlEnv.ProductVersion}</td></tr>");
        sb.AppendLine($"<tr><th>ProductLevel</th><td>{sqlEnv.ProductLevel}</td></tr>");
        sb.AppendLine($"<tr><th>Edition</th><td>{sqlEnv.Edition}</td></tr>");
        sb.AppendLine($"<tr><th>InstanceName</th><td>{sqlEnv.InstanceName}</td></tr>");
        sb.AppendLine($"<tr><th>CompatibilityLevel</th><td>{sqlEnv.CompatibilityLevel}</td></tr>");
        sb.AppendLine("</table>");

        sb.AppendLine("<h2>Error summary</h2>");
        sb.AppendLine("<table><tr><th>Category</th><th>SqlErrorNumber</th><th>Count</th></tr>");
        foreach (var e in errorGroups)
        {
            sb.AppendLine($"<tr><td>{e.ErrorCategory}</td><td>{e.SqlErrorNumber}</td><td>{e.Count}</td></tr>");
        }
        sb.AppendLine("</table>");

        if (options.IncludeSlowSamples)
        {
            sb.AppendLine("<h2>Top slow samples</h2>");
            sb.AppendLine("<table><tr><th>WorkerId</th><th>Iteration</th><th>DurationMs</th><th>Success</th><th>RetryAttempt</th><th>Spid</th><th>ErrorCategory</th></tr>");
            foreach (var s in slowest)
            {
                sb.AppendLine($"<tr><td>{s.WorkerId}</td><td>{s.Iteration}</td><td>{s.DurationMs}</td><td>{s.Success}</td><td>{s.RetryAttempt}</td><td>{s.Spid}</td><td>{s.ErrorCategory}</td></tr>");
            }
            sb.AppendLine("</table>");
        }

        if (options.IncludeDmvSection && dmvSnapshots is not null)
        {
            sb.AppendLine("<h2>DMV snapshots</h2>");
            sb.AppendLine("<table><tr><th>Phase</th><th>Name</th><th>Rows</th><th>CollectedAtUtc</th></tr>");
            foreach (var snap in dmvSnapshots)
            {
                sb.AppendLine($"<tr><td>{snap.SnapshotPhase}</td><td>{snap.SnapshotName}</td><td>{snap.Rows.Count}</td><td>{snap.CollectedAtUtc:O}</td></tr>");
            }
            sb.AppendLine("</table>");
        }

        sb.AppendLine("</body></html>");

        Directory.CreateDirectory(Path.GetDirectoryName(filePath)!);
        await File.WriteAllTextAsync(filePath, sb.ToString(), cancellationToken);
    }
}