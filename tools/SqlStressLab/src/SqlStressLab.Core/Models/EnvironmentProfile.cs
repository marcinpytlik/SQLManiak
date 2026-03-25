namespace SqlStressLab.Core.Models;

public sealed class EnvironmentProfile
{
    public string Name { get; set; } = "";
    public string Description { get; set; } = "";
    public string Server { get; set; } = "";
    public string Database { get; set; } = "";
    public string Authentication { get; set; } = "";
    public List<string> Tags { get; set; } = new();
}