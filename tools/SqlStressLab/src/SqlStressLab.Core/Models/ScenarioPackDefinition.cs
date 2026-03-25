namespace SqlStressLab.Core.Models;

public sealed class ScenarioPackDefinition
{
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public List<string> ScenarioNames { get; set; } = new();
}