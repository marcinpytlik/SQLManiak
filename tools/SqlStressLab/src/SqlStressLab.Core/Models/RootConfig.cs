namespace SqlStressLab.Core.Models;

public sealed class RootConfig
{
    public string ProfileName { get; set; } = "default";
    public string ScenarioName { get; set; } = "General";
    public SqlAuthOptions Connection { get; set; } = new();
    public ExecutionConfig Execution { get; set; } = new();
    public List<SqlParameterDefinition>? Parameters { get; set; }
    public OutputOptions Output { get; set; } = new();
    public RetryOptions Retry { get; set; } = new();
    public SqlOutputOptions SqlOutput { get; set; } = new();
}