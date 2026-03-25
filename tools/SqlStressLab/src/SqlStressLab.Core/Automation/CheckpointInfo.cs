namespace SqlStressLab.Core.Automation;

public sealed class CheckpointInfo
{
    public string SessionId { get; set; } = "";
    public string ExecutionType { get; set; } = ""; // Batch / Runbook
    public int StepOrder { get; set; }
    public string StepName { get; set; } = "";
    public string StepType { get; set; } = "";
    public string Status { get; set; } = CheckpointStatus.Pending;
    public DateTime StartedAtUtc { get; set; }
    public DateTime? FinishedAtUtc { get; set; }
    public string? RunId { get; set; }
    public int AttemptNumber { get; set; }
    public string? ErrorMessage { get; set; }
}