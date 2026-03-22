namespace SqlStressLab.Core.Models;

public sealed class ProgressSnapshot
{
    public string RunId { get; set; } = "";
    public int TotalPlannedExecutions { get; set; }
    public int CompletedExecutions { get; set; }
    public int SuccessCount { get; set; }
    public int ErrorCount { get; set; }
    public int RetryCount { get; set; }
    public DateTime StartedAtUtc { get; set; }
    public DateTime LastUpdatedAtUtc { get; set; }
}