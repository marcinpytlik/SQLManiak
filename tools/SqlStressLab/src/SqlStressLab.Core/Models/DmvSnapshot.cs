namespace SqlStressLab.Core.Models;

public sealed class DmvSnapshot
{
    public string RunId { get; set; } = "";
    public string SnapshotPhase { get; set; } = ""; // Before / After
    public string SnapshotName { get; set; } = "";  // Requests / WaitingTasks / Locks / Sessions
    public DateTime CollectedAtUtc { get; set; }
    public List<DmvSnapshotRow> Rows { get; set; } = new();
}