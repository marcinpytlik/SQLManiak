namespace SqlStressLab.Core.Models;

public sealed class SelfCheckResult
{
    public bool Success { get; set; }
    public List<string> PassedChecks { get; set; } = new();
    public List<string> FailedChecks { get; set; } = new();
    public List<string> Warnings { get; set; } = new();
}