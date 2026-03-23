using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class ScenarioPlanner
{
    public static ScenarioExecutionPlan Build(RootConfig config)
    {
        var scenario = BuiltInScenarioCatalog.Get(config.ScenarioName);
        var assignments = WorkerAssignmentFactory.Create(config, scenario);

        return new ScenarioExecutionPlan
        {
            Scenario = scenario,
            WorkerAssignments = assignments,
            EffectiveSetupScriptFile = string.IsNullOrWhiteSpace(config.Lifecycle.SetupScriptFile)
                ? scenario.DefaultSetupScriptFile
                : config.Lifecycle.SetupScriptFile,
            EffectiveCleanupScriptFile = string.IsNullOrWhiteSpace(config.Lifecycle.CleanupScriptFile)
                ? scenario.DefaultCleanupScriptFile
                : config.Lifecycle.CleanupScriptFile
        };
    }
}