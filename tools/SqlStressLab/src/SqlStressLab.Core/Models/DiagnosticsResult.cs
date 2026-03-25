namespace SqlStressLab.Core.Models;

public sealed class DiagnosticsResult
{
    public bool Success { get; set; }
    public List<string> Messages { get; set; } = new();
}