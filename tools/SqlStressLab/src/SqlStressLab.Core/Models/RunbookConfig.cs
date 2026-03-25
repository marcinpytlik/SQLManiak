namespace SqlStressLab.Core.Models;

public sealed class RunbookConfig
{
    public bool Enabled { get; set; } = false;
    public List<string> Steps { get; set; } = new();
}