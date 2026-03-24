namespace SqlStressLab.Core.Models;

public sealed class RunbookConfig
{
    public string Name { get; set; } = "default-runbook";
    public bool StopOnError { get; set; } = true;
    public List<RunbookStep> Steps { get; set; } = new();
}