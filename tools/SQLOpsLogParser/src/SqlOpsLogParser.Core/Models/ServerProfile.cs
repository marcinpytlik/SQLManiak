namespace SqlOpsLogParser.Core.Models;

public sealed class ServerProfile
{
    public string Name { get; set; } = string.Empty;
    public string Server { get; set; } = string.Empty;
    public string Database { get; set; } = "master";
    public string Authentication { get; set; } = "Windows";
    public string? UserName { get; set; }
    public string? Password { get; set; }
    public bool Encrypt { get; set; } = true;
    public bool TrustServerCertificate { get; set; } = true;
    public int ConnectTimeoutSeconds { get; set; } = 15;
}