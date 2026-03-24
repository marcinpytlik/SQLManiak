namespace SqlStressLab.Core.Models;

public sealed class ListRunsOptions
{
    public int Top { get; set; } = 20;
    public string? ProfileName { get; set; }
    public string? ScenarioName { get; set; }
}