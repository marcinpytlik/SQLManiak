namespace SqlStressLab.Core.Models;

public sealed class BundleOptions
{
    public bool Enabled { get; set; } = false;
    public string OutputFile { get; set; } = "";
    public List<string> IncludeFiles { get; set; } = new();
}