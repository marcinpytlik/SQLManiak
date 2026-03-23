using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class WorkerAssignmentFactory
{
    public static List<WorkerAssignment> Create(RootConfig config, ScenarioDefinition scenario)
    {
        var assignments = new List<WorkerAssignment>();

        for (int i = 1; i <= config.Execution.Workers; i++)
        {
            assignments.Add(new WorkerAssignment
            {
                WorkerId = i,
                Role = ResolveRole(i, scenario.Name),
                CommandTextOverride = ResolveCommandOverride(i, scenario.Name, config),
                CommandTypeOverride = ResolveCommandTypeOverride(i, scenario.Name, config)
            });
        }

        return assignments;
    }

    private static string ResolveRole(int workerId, string scenarioName)
    {
        return scenarioName switch
        {
            "DeadlockPair" => workerId % 2 == 0 ? "DeadlockB" : "DeadlockA",
            "ReadStorm" => "Reader",
            "WriteStorm" => "Writer",
            "BlockingHotRow" => "Blocker",
            _ => "Default"
        };
    }

    private static string? ResolveCommandOverride(int workerId, string scenarioName, RootConfig config)
    {
        if (scenarioName == "DeadlockPair")
        {
            return workerId % 2 == 0
                ? "dbo.usp_DeadlockWorkerB"
                : "dbo.usp_DeadlockWorkerA";
        }

        return null;
    }

    private static string? ResolveCommandTypeOverride(int workerId, string scenarioName, RootConfig config)
    {
        if (scenarioName == "DeadlockPair")
            return "StoredProcedure";

        return null;
    }
}