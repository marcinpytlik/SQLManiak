namespace SqlOpsToolkit.Core.Models;

public sealed class ToolExecutionContext
{
    public DateTime StartedAtUtc { get; init; } = DateTime.UtcNow;
    public string WorkingDirectory { get; init; } = Directory.GetCurrentDirectory();
    public string MachineName { get; init; } = Environment.MachineName;
}