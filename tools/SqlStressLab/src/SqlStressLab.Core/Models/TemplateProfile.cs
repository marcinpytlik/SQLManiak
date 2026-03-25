namespace SqlStressLab.Core.Models;

public sealed class TemplateProfile
{
    public string Name { get; set; } = "";
    public string BaseProfilePath { get; set; } = "";
    public Dictionary<string, string> Variables { get; set; } = new();
}