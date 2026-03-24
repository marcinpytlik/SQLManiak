namespace SqlStressLab.Core.Models;

public sealed class ConsoleReportOptions
{
    public bool Enabled { get; set; } = true;
    public bool ShowTopWaits { get; set; } = true;
    public int TopWaitsCount { get; set; } = 10;
    public bool ShowBlockingSummary { get; set; } = true;
    public bool ShowBaselineDiff { get; set; } = true;
    public bool ShowArtifactPaths { get; set; } = true;
}