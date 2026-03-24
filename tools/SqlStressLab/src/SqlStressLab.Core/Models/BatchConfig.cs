namespace SqlStressLab.Core.Models;

public sealed class BatchConfig
{
    public string Name { get; set; } = "default-batch";
    public bool StopOnError { get; set; } = true;
    public List<BatchItem> Items { get; set; } = new();
}