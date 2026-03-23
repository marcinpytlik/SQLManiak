namespace SqlStressLab.Core.Models;

public sealed class ScenarioDefinition
{
    public string Name { get; set; } = "General";
    public string Description { get; set; } = "";
    public string ScenarioType { get; set; } = "General";

    public string? DefaultSetupScriptFile { get; set; }
    public string? DefaultCleanupScriptFile { get; set; }

    public bool RequiresWorkerPairing { get; set; }
    public bool RequiresDmvSnapshotBefore { get; set; } = true;
    public bool RequiresDmvSnapshotAfter { get; set; } = true;
}