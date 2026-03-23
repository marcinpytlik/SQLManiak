namespace SqlStressLab.Core.Models;

public sealed class EnvironmentInfo
{
    public string EnvironmentName { get; set; } = "Lab";
    public string MachineName { get; set; } = Environment.MachineName;
    public string UserName { get; set; } = Environment.UserName;
    public string OsVersion { get; set; } = Environment.OSVersion.ToString();
    public string DotNetVersion { get; set; } = System.Environment.Version.ToString();
    public string ApplicationName { get; set; } = "SqlStressLab";
}