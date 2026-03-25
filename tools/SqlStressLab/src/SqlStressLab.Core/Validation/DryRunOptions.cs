namespace SqlStressLab.Core.Models;

public sealed class DryRunOptions
{
    public bool Enabled { get; set; } = false;
    public bool PrintToConsole { get; set; } = true;
    public bool WriteResolvedConfigFile { get; set; } = true;
    public string OutputDirectory { get; set; } = "outputs";
}