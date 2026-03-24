namespace SqlStressLab.Core.Models;

public sealed class BundleOptions
{
    public bool Enabled { get; set; } = true;
    public string OutputRootDirectory { get; set; } = "outputs";
    public bool ZipAfterRun { get; set; } = true;
    public bool IncludeRawDmvJson { get; set; } = true;
    public bool IncludeReports { get; set; } = true;
}