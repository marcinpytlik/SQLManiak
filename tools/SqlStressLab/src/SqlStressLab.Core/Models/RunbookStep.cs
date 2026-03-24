namespace SqlStressLab.Core.Models;

public sealed class RunbookStep
{
    public string StepType { get; set; } = ""; // setup-script / run-profile / compare / report / bundle / cleanup-script
    public string? FilePath { get; set; }
    public string? ProfilePath { get; set; }
    public string? RunId { get; set; }
    public string? CurrentRunId { get; set; }
    public string? BaselineRunId { get; set; }
    public int DelayAfterMs { get; set; } = 0;
}