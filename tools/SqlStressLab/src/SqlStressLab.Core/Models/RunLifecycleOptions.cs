namespace SqlStressLab.Core.Models;

public sealed class RunLifecycleOptions
{
    public bool SetupEnabled { get; set; } = false;
    public bool CleanupEnabled { get; set; } = false;

    public string? SetupScriptFile { get; set; }
    public string? CleanupScriptFile { get; set; }

    public bool StopRunWhenSetupFails { get; set; } = true;
    public bool ContinueWhenCleanupFails { get; set; } = true;
}