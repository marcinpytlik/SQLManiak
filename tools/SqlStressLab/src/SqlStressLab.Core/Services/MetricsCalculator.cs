using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public static class MetricsCalculator
{
    public static StressSummary BuildSummary(List<ExecutionSample> samples)
    {
        var success = samples.Where(x => x.Success).OrderBy(x => x.DurationMs).ToList();

        long Percentile(double p)
        {
            if (success.Count == 0)
                return 0;

            var index = (int)Math.Ceiling((p / 100.0) * success.Count) - 1;
            index = Math.Clamp(index, 0, success.Count - 1);
            return success[index].DurationMs;
        }

        var totalDurationMs = success.Sum(x => x.DurationMs);

        return new StressSummary
        {
            TotalExecutions = samples.Count,
            SuccessCount = success.Count,
            ErrorCount = samples.Count - success.Count,
            AvgDurationMs = success.Count == 0 ? 0 : success.Average(x => x.DurationMs),
            MinDurationMs = success.Count == 0 ? 0 : success.Min(x => x.DurationMs),
            MaxDurationMs = success.Count == 0 ? 0 : success.Max(x => x.DurationMs),
            P50DurationMs = Percentile(50),
            P95DurationMs = Percentile(95),
            P99DurationMs = Percentile(99),
            ThroughputPerSecond = totalDurationMs == 0 ? 0 : (success.Count / (totalDurationMs / 1000.0))
        };
    }
}