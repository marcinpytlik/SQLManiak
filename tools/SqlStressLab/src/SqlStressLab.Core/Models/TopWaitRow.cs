namespace SqlStressLab.Core.Models;

public sealed class TopWaitRow
{
    public string WaitType { get; set; } = "";
    public long WaitTimeMs { get; set; }
    public long WaitingTasksCount { get; set; }
    public decimal Percentage { get; set; }
}