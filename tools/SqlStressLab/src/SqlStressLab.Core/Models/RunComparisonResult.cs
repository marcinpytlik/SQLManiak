namespace SqlStressLab.Core.Models;

public sealed class RunComparisonResult
{
    public string RunId { get; set; } = "";
    public string BaselineRunId { get; set; } = "";

    public string CurrentProfileName { get; set; } = "";
    public string BaselineProfileName { get; set; } = "";

    public string CurrentScenarioName { get; set; } = "";
    public string BaselineScenarioName { get; set; } = "";

    public double CurrentAvgDurationMs { get; set; }
    public double BaselineAvgDurationMs { get; set; }
    public double AvgDurationDeltaMs { get; set; }

    public long CurrentP95DurationMs { get; set; }
    public long BaselineP95DurationMs { get; set; }
    public long P95DurationDeltaMs { get; set; }

    public double CurrentThroughputPerSecond { get; set; }
    public double BaselineThroughputPerSecond { get; set; }
    public double ThroughputDelta { get; set; }

    public int CurrentErrorCount { get; set; }
    public int BaselineErrorCount { get; set; }
    public int ErrorCountDelta { get; set; }

    public int CurrentRetryCount { get; set; }
    public int BaselineRetryCount { get; set; }
    public int RetryCountDelta { get; set; }

    public bool IncludeSampleLevelDiff { get; set; }
    public bool IsRegression { get; set; }

    public DateTime ComparedAtUtc { get; set; }
    public string SummaryText { get; set; } = "";
}