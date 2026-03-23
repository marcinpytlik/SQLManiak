namespace SqlStressLab.Core.Models;

public sealed class SqlParameterDefinition
{
    public string Name { get; set; } = "";
    public string Type { get; set; } = "NVARCHAR";
    public string Mode { get; set; } = "Fixed";

    public string? Value { get; set; }

    public string? Min { get; set; }
    public string? Max { get; set; }

    public string? Start { get; set; }
    public string? Increment { get; set; }
}