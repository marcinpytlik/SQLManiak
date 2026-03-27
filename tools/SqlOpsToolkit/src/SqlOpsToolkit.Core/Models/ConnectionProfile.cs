using SqlOpsToolkit.Core.Enums;

namespace SqlOpsToolkit.Core.Models;

public sealed class ConnectionProfile
{
    public string Name { get; init; } = string.Empty;
    public string Server { get; init; } = string.Empty;
    public int Port { get; init; } = 1433;
    public string Database { get; init; } = "master";
    public AuthenticationMode AuthenticationMode { get; init; } = AuthenticationMode.Windows;
    public string User { get; init; } = string.Empty;
    public string Password { get; init; } = string.Empty;
    public bool Encrypt { get; init; } = true;
    public bool TrustServerCertificate { get; init; } = true;
    public IReadOnlyList<string> Tags { get; init; } = Array.Empty<string>();
}