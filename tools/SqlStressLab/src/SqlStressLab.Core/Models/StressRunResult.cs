namespace SqlStressLab.Core.Models;

public sealed class StressRunResult
{
    public string RunId { get; set; } = "";
    public DateTime StartedAtUtc { get; set; }
    public DateTime FinishedAtUtc { get; set; }

    public int RetryCount { get; set; }

    public StressSummary Summary { get; set; } = new();
    public List<ExecutionSample> Samples { get; set; } = new();
}