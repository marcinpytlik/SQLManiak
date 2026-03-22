namespace SqlStressLab.Core.Models;

public sealed class SqlAuthOptions
{
    public string Server { get; set; } = "";
    public string Database { get; set; } = "";
    public string Authentication { get; set; } = "SqlPassword";
    public string? UserName { get; set; }
    public string? Password { get; set; }
    public bool Encrypt { get; set; } = true;
    public bool TrustServerCertificate { get; set; } = true;
    public string ApplicationName { get; set; } = "SqlStressLab";
}