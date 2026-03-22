namespace SqlStressLab.Core.Models;

public sealed class SqlParameterDefinition
{
    public string Name { get; set; } = "";
    public string Type { get; set; } = "String";
    public string Mode { get; set; } = "Fixed";
    public string? Value { get; set; }
    public int? Min { get; set; }
    public int? Max { get; set; }
}