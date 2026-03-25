namespace SqlStressLab.Core.Models;

public sealed class RunbookConfig
{
    public bool Enabled { get; set; } = false;
    public List<RunbookStep> Steps { get; set; } = new();
}