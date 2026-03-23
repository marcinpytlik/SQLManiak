namespace SqlStressLab.Core.Models;

public sealed class HtmlReportOptions
{
    public bool Enabled { get; set; } = true;
    public string Directory { get; set; } = "outputs";
    public bool IncludeDmvSection { get; set; } = true;
    public bool IncludeSlowSamples { get; set; } = true;
    public int TopSlowSamplesCount { get; set; } = 20;
}