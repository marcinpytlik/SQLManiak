namespace SqlStressLab.Core.Models;

public sealed class BatchItem
{
    public string ProfilePath { get; set; } = "";
    public string? Label { get; set; }
    public int DelayAfterMs { get; set; } = 0;
}