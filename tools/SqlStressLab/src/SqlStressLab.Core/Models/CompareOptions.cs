namespace SqlStressLab.Core.Models;

public sealed class CompareOptions
{
    public bool Enabled { get; set; } = false;
    public string Mode { get; set; } = "PreviousRun"; // PreviousRun / SpecificRunId
    public string? BaselineRunId { get; set; }
    public bool IncludeSampleLevelDiff { get; set; } = false;
}