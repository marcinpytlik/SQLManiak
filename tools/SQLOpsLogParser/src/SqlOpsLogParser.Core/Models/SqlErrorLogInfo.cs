namespace SqlOpsLogParser.Core.Models;

public sealed class SqlErrorLogInfo
{
    public int ArchiveNumber { get; set; }
    public DateTime LogDate { get; set; }
    public long LogFileSizeBytes { get; set; }
}