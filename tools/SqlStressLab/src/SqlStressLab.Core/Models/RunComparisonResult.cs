namespace SqlStressLab.Core.Models;

public sealed class RunComparisonResult
{
    public string RunId { get; set; } = "";
    public string BaselineRunId { get; set; } = "";

    public string CurrentProfileName { get; set; } = "";
    public string BaselineProfileName { get; set; } = "";

    public string CurrentScenarioName { get; set; } = "";
    public string BaselineScenarioName { get; set; } = "";

    public double AvgDurationDeltaMs { get; set; }
    public long P95DurationDeltaMs { get; set; }
    public double ThroughputDelta { get; set; }
    public int ErrorCountDelta { get; set; }
    public int RetryCountDelta { get; set; }

    public bool IsRegression { get; set; }

    public DateTime ComparedAtUtc { get; set; } = DateTime.UtcNow;

    public string SummaryText { get; set; } = "";
}