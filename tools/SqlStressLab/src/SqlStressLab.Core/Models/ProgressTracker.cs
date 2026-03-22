using System.Threading;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class ProgressTracker
{
    private int _completed;
    private int _success;
    private int _errors;
    private int _retries;

    public ProgressTracker(string runId, int totalPlannedExecutions)
    {
        Snapshot = new ProgressSnapshot
        {
            RunId = runId,
            TotalPlannedExecutions = totalPlannedExecutions,
            StartedAtUtc = DateTime.UtcNow,
            LastUpdatedAtUtc = DateTime.UtcNow
        };
    }

    public ProgressSnapshot Snapshot { get; }

    public void MarkSuccess()
    {
        Interlocked.Increment(ref _completed);
        Interlocked.Increment(ref _success);
        Refresh();
    }

    public void MarkError()
    {
        Interlocked.Increment(ref _completed);
        Interlocked.Increment(ref _errors);
        Refresh();
    }

    public void MarkRetry()
    {
        Interlocked.Increment(ref _retries);
        Refresh();
    }

    private void Refresh()
    {
        Snapshot.CompletedExecutions = _completed;
        Snapshot.SuccessCount = _success;
        Snapshot.ErrorCount = _errors;
        Snapshot.RetryCount = _retries;
        Snapshot.LastUpdatedAtUtc = DateTime.UtcNow;
    }
}