namespace SqlStressLab.Core.Models;

public sealed class StressSummary
{
    public int TotalExecutions { get; set; }
    public int SuccessCount { get; set; }
    public int ErrorCount { get; set; }
    public double AvgDurationMs { get; set; }
    public long MinDurationMs { get; set; }
    public long MaxDurationMs { get; set; }
    public long P50DurationMs { get; set; }
    public long P95DurationMs { get; set; }
    public long P99DurationMs { get; set; }
    public double ThroughputPerSecond { get; set; }
}