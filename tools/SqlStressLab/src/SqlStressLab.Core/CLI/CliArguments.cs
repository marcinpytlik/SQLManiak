namespace SqlStressLab.Core.Models;

public sealed class CliArguments
{
    public string Command { get; set; } = "run";

    public string ProfilePath { get; set; } = "";

    public string? CurrentRunId { get; set; }
    public string? BaselineRunId { get; set; }

    public string? ProfileName { get; set; }

    public int Top { get; set; } = 10;

    public bool IncludeSampleLevelDiff { get; set; } = false;
}