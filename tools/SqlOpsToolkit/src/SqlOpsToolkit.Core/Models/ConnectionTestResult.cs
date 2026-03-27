namespace SqlOpsToolkit.Core.Models;

public sealed class ConnectionTestResult
{
    public string ProfileName { get; init; } = string.Empty;
    public string Server { get; init; } = string.Empty;
    public bool ConnectOk { get; init; }
    public string Message { get; init; } = string.Empty;
    public DateTime CheckedAtUtc { get; init; } = DateTime.UtcNow;
    public long? DurationMs { get; init; }
}