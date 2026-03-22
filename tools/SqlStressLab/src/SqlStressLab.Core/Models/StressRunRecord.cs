namespace SqlStressLab.Core.Models;

public sealed class StressRunRecord
{
    public string RunId { get; set; } = "";
    public string ProfileName { get; set; } = "";
    public string ScenarioName { get; set; } = "General";
    public string ServerName { get; set; } = "";
    public string DatabaseName { get; set; } = "";
    public string CommandType { get; set; } = "";
    public string ExecutionMode { get; set; } = "";
    public int Workers { get; set; }
    public int IterationsPerWorker { get; set; }
    public int TotalExecutions { get; set; }
    public int SuccessCount { get; set; }
    public int ErrorCount { get; set; }
    public int RetryCount { get; set; }
    public double AvgDurationMs { get; set; }
    public long MinDurationMs { get; set; }
    public long P50DurationMs { get; set; }
    public long P95DurationMs { get; set; }
    public long P99DurationMs { get; set; }
    public long MaxDurationMs { get; set; }
    public double ThroughputPerSecond { get; set; }
    public DateTime StartedAtUtc { get; set; }
    public DateTime FinishedAtUtc { get; set; }
    public long WallClockMs { get; set; }
}