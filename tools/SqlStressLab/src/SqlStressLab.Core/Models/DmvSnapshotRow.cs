namespace SqlStressLab.Core.Models;

public sealed class DmvSnapshotRow
{
    public string RunId { get; set; } = "";
    public string SnapshotPhase { get; set; } = "";
    public string SnapshotName { get; set; } = "";
    public DateTime CollectedAtUtc { get; set; }
    public string RowJson { get; set; } = "";
}