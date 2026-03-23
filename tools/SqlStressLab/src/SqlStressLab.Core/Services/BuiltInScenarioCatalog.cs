using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class BuiltInScenarioCatalog
{
    public static ScenarioDefinition Get(string name)
    {
        return name switch
        {
            "BlockingHotRow" => new ScenarioDefinition
            {
                Name = "BlockingHotRow",
                Description = "Wszyscy workerzy uderzają w ten sam rekord, aby wywołać blocking i LCK waits.",
                ScenarioType = "BlockingHotRow",
                DefaultSetupScriptFile = "profiles/setup-blocking-hotrow.sql",
                DefaultCleanupScriptFile = "profiles/cleanup-blocking-hotrow.sql",
                RequiresWorkerPairing = false,
                RequiresDmvSnapshotBefore = true,
                RequiresDmvSnapshotAfter = true
            },

            "DeadlockPair" => new ScenarioDefinition
            {
                Name = "DeadlockPair",
                Description = "Parowanie workerów A/B w celu prowokowania deadlocków.",
                ScenarioType = "DeadlockPair",
                DefaultSetupScriptFile = "profiles/setup-deadlock-pair.sql",
                DefaultCleanupScriptFile = "profiles/cleanup-deadlock-pair.sql",
                RequiresWorkerPairing = true,
                RequiresDmvSnapshotBefore = true,
                RequiresDmvSnapshotAfter = true
            },

            "ReadStorm" => new ScenarioDefinition
            {
                Name = "ReadStorm",
                Description = "Równoległy odczyt dużej liczby zapytań typu SELECT.",
                ScenarioType = "ReadStorm",
                DefaultSetupScriptFile = null,
                DefaultCleanupScriptFile = null,
                RequiresWorkerPairing = false,
                RequiresDmvSnapshotBefore = true,
                RequiresDmvSnapshotAfter = true
            },

            "WriteStorm" => new ScenarioDefinition
            {
                Name = "WriteStorm",
                Description = "Równoległe inserty lub update powodujące presję na log i zasoby zapisu.",
                ScenarioType = "WriteStorm",
                DefaultSetupScriptFile = "profiles/setup-write-storm.sql",
                DefaultCleanupScriptFile = "profiles/cleanup-write-storm.sql",
                RequiresWorkerPairing = false,
                RequiresDmvSnapshotBefore = true,
                RequiresDmvSnapshotAfter = true
            },

            _ => new ScenarioDefinition
            {
                Name = "General",
                Description = "Uniwersalny scenariusz bez specjalnej orkiestracji.",
                ScenarioType = "General",
                RequiresWorkerPairing = false,
                RequiresDmvSnapshotBefore = true,
                RequiresDmvSnapshotAfter = true
            }
        };
    }
}