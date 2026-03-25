namespace SqlStressLab.Core.Models;

public sealed class DiagnosticsResult
{
    public string EnvironmentName { get; set; } = "";
    public string MachineName { get; set; } = "";
    public bool SqlConnectivityOk { get; set; }
    public bool OutputDirectoryWritable { get; set; }
    public bool PerfCountersOk { get; set; }
    public bool XeSessionOk { get; set; }
    public List<string> Notes { get; set; } = new();
}