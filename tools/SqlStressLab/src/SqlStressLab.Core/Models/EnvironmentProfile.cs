namespace SqlStressLab.Core.Models;

public sealed class EnvironmentProfile
{
    public string Name { get; set; } = "";
    public Dictionary<string, string> Variables { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}