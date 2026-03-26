namespace SqlOpsLogParser.Core.Models;

public sealed class JobStepInfo
{
    public Guid JobId { get; set; }
    public string JobName { get; set; } = string.Empty;

    public int StepId { get; set; }
    public string StepName { get; set; } = string.Empty;
    public string Subsystem { get; set; } = string.Empty;
    public string DatabaseName { get; set; } = string.Empty;
    public string Command { get; set; } = string.Empty;

    public int OnSuccessAction { get; set; }
    public int OnFailAction { get; set; }
}