namespace SqlStressLab.Core.Enums;

public enum WorkerRoleType
{
    Default,
    DeadlockA,
    DeadlockB,
    Reader,
    Writer,
    Blocker
}