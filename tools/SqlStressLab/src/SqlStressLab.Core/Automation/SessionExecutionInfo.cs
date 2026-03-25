namespace SqlStressLab.Core.Automation;

public sealed class SessionExecutionInfo
{
    public string SessionId { get; set; } = "";
    public string ExecutionType { get; set; } = ""; // Batch / Runbook
    public string Name { get; set; } = "";
    public string Status { get; set; } = "Created";
    public DateTime StartedAtUtc { get; set; }
    public DateTime? FinishedAtUtc { get; set; }
    public int TotalSteps { get; set; }
    public int SucceededSteps { get; set; }
    public int FailedSteps { get; set; }
    public int SkippedSteps { get; set; }
}