namespace SqlStressLab.Core.Models;

public sealed class PublishBundleOptions
{
    public bool Enabled { get; set; } = false;
    public string OutputDirectory { get; set; } = "";
    public string Runtime { get; set; } = "win-x64";
    public bool SelfContained { get; set; } = false;
    public bool IncludeProfilesDirectory { get; set; } = true;
}