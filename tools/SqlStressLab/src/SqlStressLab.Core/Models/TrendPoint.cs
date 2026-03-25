namespace SqlStressLab.Core.Models;

public sealed class TrendPoint
{
    public string RunId { get; set; } = "";
    public DateTime StartedAtUtc { get; set; }

    public double AvgDurationMs { get; set; }
    public long P95DurationMs { get; set; }
    public double ThroughputPerSecond { get; set; }
    public int ErrorCount { get; set; }
    public int RetryCount { get; set; }
}