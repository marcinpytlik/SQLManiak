namespace SqlStressLab.Core.Models;

public sealed class MarkdownReportOptions
{
    public bool Enabled { get; set; } = true;
    public string Directory { get; set; } = "outputs";
    public bool IncludeTopSlowestSamples { get; set; } = true;
    public int TopSlowestSamplesCount { get; set; } = 20;
    public bool IncludeErrorSummary { get; set; } = true;
}