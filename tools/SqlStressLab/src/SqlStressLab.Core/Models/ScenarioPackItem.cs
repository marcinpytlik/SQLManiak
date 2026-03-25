namespace SqlStressLab.Core.Models;

public sealed class ScenarioPackItem
{
    public string ScenarioName { get; set; } = "";
    public string TemplatePath { get; set; } = "";
    public string DefaultEnvironment { get; set; } = "";
}