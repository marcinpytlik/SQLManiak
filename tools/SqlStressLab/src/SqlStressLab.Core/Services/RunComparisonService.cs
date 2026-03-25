using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class RunComparisonService
{
    public static RunComparisonResult Compare(
        StressRunRecord currentRun,
        StressRunRecord baselineRun,
        bool includeSampleLevelDiff)
    {
        ArgumentNullException.ThrowIfNull(currentRun);
        ArgumentNullException.ThrowIfNull(baselineRun);

        var avgDelta = currentRun.AvgDurationMs - baselineRun.AvgDurationMs;
        var p95Delta = currentRun.P95DurationMs - baselineRun.P95DurationMs;
        var throughputDelta = currentRun.ThroughputPerSecond - baselineRun.ThroughputPerSecond;
        var errorDelta = currentRun.ErrorCount - baselineRun.ErrorCount;
        var retryDelta = currentRun.RetryCount - baselineRun.RetryCount;

        var isRegression =
            avgDelta > 0 ||
            p95Delta > 0 ||
            throughputDelta < 0 ||
            errorDelta > 0 ||
            retryDelta > 0;

        return new RunComparisonResult
        {
            RunId = currentRun.RunId,
            BaselineRunId = baselineRun.RunId,
            CurrentProfileName = currentRun.ProfileName,
            BaselineProfileName = baselineRun.ProfileName,
            CurrentScenarioName = currentRun.ScenarioName,
            BaselineScenarioName = baselineRun.ScenarioName,
            AvgDurationDeltaMs = avgDelta,
            P95DurationDeltaMs = p95Delta,
            ThroughputDelta = throughputDelta,
            ErrorCountDelta = errorDelta,
            RetryCountDelta = retryDelta,
            IsRegression = isRegression,
            SummaryText = isRegression ? "Regression detected" : "No regression detected"
        };
    }
}