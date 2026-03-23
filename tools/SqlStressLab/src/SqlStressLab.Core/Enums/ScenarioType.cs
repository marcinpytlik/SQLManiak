namespace SqlStressLab.Core.Enums;

public enum ScenarioType
{
    General,
    BlockingHotRow,
    DeadlockPair,
    ReadStorm,
    WriteStorm
}