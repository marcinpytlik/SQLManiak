using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class RunComparisonService
{
    public static RunComparisonResult Compare(
        StressRunRecord current,
        StressRunRecord baseline,
        bool includeSampleLevelDiff = false)
    {
        ArgumentNullException.ThrowIfNull(current);
        ArgumentNullException.ThrowIfNull(baseline);

        var result = new RunComparisonResult
        {
            RunId = current.RunId,
            BaselineRunId = baseline.RunId,

            CurrentProfileName = current.ProfileName,
            BaselineProfileName = baseline.ProfileName,

            CurrentScenarioName = current.ScenarioName,
            BaselineScenarioName = baseline.ScenarioName,

            CurrentAvgDurationMs = current.AvgDurationMs,
            BaselineAvgDurationMs = baseline.AvgDurationMs,
            AvgDurationDeltaMs = current.AvgDurationMs - baseline.AvgDurationMs,

            CurrentP95DurationMs = current.P95DurationMs,
            BaselineP95DurationMs = baseline.P95DurationMs,
            P95DurationDeltaMs = current.P95DurationMs - baseline.P95DurationMs,

            CurrentThroughputPerSecond = current.ThroughputPerSecond,
            BaselineThroughputPerSecond = baseline.ThroughputPerSecond,
            ThroughputDelta = current.ThroughputPerSecond - baseline.ThroughputPerSecond,

            CurrentErrorCount = current.ErrorCount,
            BaselineErrorCount = baseline.ErrorCount,
            ErrorCountDelta = current.ErrorCount - baseline.ErrorCount,

            CurrentRetryCount = current.RetryCount,
            BaselineRetryCount = baseline.RetryCount,
            RetryCountDelta = current.RetryCount - baseline.RetryCount,

            IncludeSampleLevelDiff = includeSampleLevelDiff,
            ComparedAtUtc = DateTime.UtcNow
        };

        result.IsRegression = IsRegression(result);

        result.SummaryText =
            $"AVG Δ={result.AvgDurationDeltaMs:F2} ms; " +
            $"P95 Δ={result.P95DurationDeltaMs}; " +
            $"THR Δ={result.ThroughputDelta:F2}; " +
            $"ERR Δ={result.ErrorCountDelta}; " +
            $"RETRY Δ={result.RetryCountDelta}; " +
            $"REGRESSION={result.IsRegression}";

        return result;
    }

    private static bool IsRegression(RunComparisonResult result)
    {
        if (result.AvgDurationDeltaMs > 0)
            return true;

        if (result.P95DurationDeltaMs > 0)
            return true;

        if (result.ThroughputDelta < 0)
            return true;

        if (result.ErrorCountDelta > 0)
            return true;

        return false;
    }
}