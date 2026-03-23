namespace SqlStressLab.Core.Models;

public sealed class WorkerAssignment
{
    public int WorkerId { get; set; }
    public string Role { get; set; } = "Default";
    public string? CommandTextOverride { get; set; }
    public string? CommandTypeOverride { get; set; }
}