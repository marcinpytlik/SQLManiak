namespace SqlStressLab.Core.Models;

public sealed class MatrixAxisDefinition
{
    public string Name { get; set; } = "";
    public List<string> Values { get; set; } = new();
}