using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class TrendAnalysisService
{
    public TrendAnalysisResult Analyze(
        string profileName,
        List<StressRunRecord> runs,
        int requestedTop)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(profileName);
        ArgumentNullException.ThrowIfNull(runs);

        var ordered = runs
            .OrderBy(x => x.StartedAtUtc)
            .TakeLast(requestedTop)
            .ToList();

        var points = ordered.Select(x => new TrendPoint
        {
            RunId = x.RunId,
            StartedAtUtc = x.StartedAtUtc,
            AvgDurationMs = x.AvgDurationMs,
            P95DurationMs = x.P95DurationMs,
            ThroughputPerSecond = x.ThroughputPerSecond,
            ErrorCount = x.ErrorCount,
            RetryCount = x.RetryCount
        }).ToList();

        return new TrendAnalysisResult
        {
            ProfileName = profileName,
            RequestedTop = requestedTop,
            Points = points,
            AvgDurationTrendDirection = CalculateDirection(points.Select(x => x.AvgDurationMs).ToList(), lowerIsBetter: true),
            P95DurationTrendDirection = CalculateDirection(points.Select(x => (double)x.P95DurationMs).ToList(), lowerIsBetter: true),
            ThroughputTrendDirection = CalculateDirection(points.Select(x => x.ThroughputPerSecond).ToList(), lowerIsBetter: false),
            ErrorTrendDirection = CalculateDirection(points.Select(x => (double)x.ErrorCount).ToList(), lowerIsBetter: true),
            SummaryVerdict = BuildVerdict(points)
        };
    }

    private static string CalculateDirection(List<double> values, bool lowerIsBetter)
    {
        if (values.Count < 2)
            return "Stable";

        var first = values.First();
        var last = values.Last();

        if (Math.Abs(last - first) < 0.0001)
            return "Stable";

        var improved = lowerIsBetter ? last < first : last > first;
        return improved ? "Improving" : "Regressing";
    }

    private static string BuildVerdict(List<TrendPoint> points)
    {
        if (points.Count < 2)
            return "Neutral";

        var first = points.First();
        var last = points.Last();

        var improved =
            last.AvgDurationMs <= first.AvgDurationMs &&
            last.P95DurationMs <= first.P95DurationMs &&
            last.ErrorCount <= first.ErrorCount;

        var regressed =
            last.AvgDurationMs > first.AvgDurationMs ||
            last.P95DurationMs > first.P95DurationMs ||
            last.ErrorCount > first.ErrorCount;

        if (improved)
            return "Improving";

        if (regressed)
            return "Regressing";

        return "Neutral";
    }
}