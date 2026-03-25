namespace SqlStressLab.Core.Models;

public sealed class PublishBundleOptions
{
    public bool Enabled { get; set; } = true;
    public bool RedactSensitiveValues { get; set; } = true;
    public bool IncludeRawSnapshots { get; set; } = false;
    public bool IncludePerfCounters { get; set; } = true;
    public string OutputRootDirectory { get; set; } = "outputs";
}