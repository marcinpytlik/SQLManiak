using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class TrendAnalysisService
{
    public TrendAnalysisResult Analyze(
        string profileName,
        List<StressRunRecord> runs,
        int top)
    {
        ArgumentNullException.ThrowIfNull(runs);

        var orderedRuns = runs
            .OrderBy(x => x.StartedAtUtc)
            .TakeLast(Math.Max(1, top))
            .ToList();

        var points = orderedRuns
            .Select(x => new TrendPoint
            {
                RunId = x.RunId,
                StartedAtUtc = x.StartedAtUtc,
                AvgDurationMs = x.AvgDurationMs,
                P95DurationMs = x.P95DurationMs,
                ThroughputPerSecond = x.ThroughputPerSecond,
                ErrorCount = x.ErrorCount
            })
            .ToList();

        var result = new TrendAnalysisResult
        {
            ProfileName = profileName,
            RequestedTop = top,
            Points = points,
            AvgDurationTrendDirection = DetectTrend(points.Select(x => x.AvgDurationMs).ToList(), lowerIsBetter: true),
            P95DurationTrendDirection = DetectTrend(points.Select(x => (double)x.P95DurationMs).ToList(), lowerIsBetter: true),
            ThroughputTrendDirection = DetectTrend(points.Select(x => x.ThroughputPerSecond).ToList(), lowerIsBetter: false),
            ErrorTrendDirection = DetectTrend(points.Select(x => (double)x.ErrorCount).ToList(), lowerIsBetter: true)
        };

        result.SummaryVerdict = BuildSummaryVerdict(result);

        return result;
    }

    private static string DetectTrend(List<double> values, bool lowerIsBetter)
    {
        if (values.Count < 2)
            return "InsufficientData";

        var first = values.First();
        var last = values.Last();

        if (Math.Abs(last - first) < 0.0001)
            return "Stable";

        if (lowerIsBetter)
        {
            return last < first ? "Improving" : "Worsening";
        }

        return last > first ? "Improving" : "Worsening";
    }

    private static string BuildSummaryVerdict(TrendAnalysisResult result)
    {
        var improving = 0;
        var worsening = 0;

        Count(result.AvgDurationTrendDirection, ref improving, ref worsening);
        Count(result.P95DurationTrendDirection, ref improving, ref worsening);
        Count(result.ThroughputTrendDirection, ref improving, ref worsening);
        Count(result.ErrorTrendDirection, ref improving, ref worsening);

        if (worsening > improving)
            return "Worsening";

        if (improving > worsening)
            return "Improving";

        return "MixedOrStable";
    }

    private static void Count(string direction, ref int improving, ref int worsening)
    {
        if (string.Equals(direction, "Improving", StringComparison.OrdinalIgnoreCase))
            improving++;

        if (string.Equals(direction, "Worsening", StringComparison.OrdinalIgnoreCase))
            worsening++;
    }
}