namespace SqlStressLab.Core.Models;

public sealed class SessionInfo
{
    public int? Spid { get; set; }
    public string? HostName { get; set; }
    public string? AppName { get; set; }
    public string? LoginName { get; set; }
    public string? DatabaseName { get; set; }
}