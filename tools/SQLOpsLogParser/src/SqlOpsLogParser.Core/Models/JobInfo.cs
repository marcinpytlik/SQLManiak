namespace SqlOpsLogParser.Core.Models;

public sealed class JobInfo
{
    public Guid JobId { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool Enabled { get; set; }
    public string OwnerLoginName { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
}