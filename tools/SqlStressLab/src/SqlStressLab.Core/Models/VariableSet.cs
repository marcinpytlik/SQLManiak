namespace SqlStressLab.Core.Models;

public sealed class VariableSet
{
    public Dictionary<string, string> Variables { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}