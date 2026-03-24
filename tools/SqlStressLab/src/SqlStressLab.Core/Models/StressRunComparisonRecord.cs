namespace SqlStressLab.Core.Models;

public sealed class StressRunComparisonRecord
{
    public string RunId { get; set; } = "";
    public string BaselineRunId { get; set; } = "";

    public double AvgDurationDeltaMs { get; set; }
    public long P95DurationDeltaMs { get; set; }
    public double ThroughputDelta { get; set; }
    public int ErrorCountDelta { get; set; }
    public int RetryCountDelta { get; set; }

    public bool IsRegression { get; set; }

    public DateTime ComparedAtUtc { get; set; }
}