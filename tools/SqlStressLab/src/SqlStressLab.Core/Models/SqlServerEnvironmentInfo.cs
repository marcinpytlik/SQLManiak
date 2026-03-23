namespace SqlStressLab.Core.Models;

public sealed class SqlServerEnvironmentInfo
{
    public string ProductVersion { get; set; } = "";
    public string ProductLevel { get; set; } = "";
    public string Edition { get; set; } = "";
    public string EngineEdition { get; set; } = "";
    public string ServerName { get; set; } = "";
    public string MachineName { get; set; } = "";
    public string InstanceName { get; set; } = "";
    public string DatabaseName { get; set; } = "";
    public int CompatibilityLevel { get; set; }
}