namespace SqlStressLab.Core.Models;

public sealed class PublishBundleOptions
{
    public bool Enabled { get; set; } = false;
    public string OutputDirectory { get; set; } = "";
}