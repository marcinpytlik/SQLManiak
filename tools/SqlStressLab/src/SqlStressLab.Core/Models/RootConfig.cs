namespace SqlStressLab.Core.Models;

public sealed class RootConfig
{
    public SqlAuthOptions Connection { get; set; } = new();
    public ExecutionConfig Execution { get; set; } = new();
    public List<SqlParameterDefinition>? Parameters { get; set; }
    public OutputOptions Output { get; set; } = new();
}