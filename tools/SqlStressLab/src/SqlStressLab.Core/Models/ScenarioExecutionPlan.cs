namespace SqlStressLab.Core.Models;

public sealed class ScenarioExecutionPlan
{
    public ScenarioDefinition Scenario { get; set; } = new();
    public List<WorkerAssignment> WorkerAssignments { get; set; } = new();

    public string? EffectiveSetupScriptFile { get; set; }
    public string? EffectiveCleanupScriptFile { get; set; }
}