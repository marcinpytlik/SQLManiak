namespace SqlStressLab.Core.Models;

public sealed class WorkerContext
{
    public int WorkerId { get; set; }
    public SessionInfo SessionInfo { get; set; } = new();
}