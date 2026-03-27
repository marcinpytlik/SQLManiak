using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Services;

public sealed class OperationalReportService(
    ITimelineService timelineService,
    IJobRepository jobRepository) : IOperationalReportService
{
    public async Task<NightlyReport> BuildNightlyReportAsync(
        ServerProfile profile,
        int hours,
        CancellationToken cancellationToken = default)
    {
        var timeline = await timelineService.GetTimelineAsync(
            new TimelineRequest
            {
                Profile = profile,
                Hours = hours
            },
            cancellationToken);

        var failedJobs = await jobRepository.GetFailedJobsAsync(
            profile,
            hours,
            null,
            cancellationToken);

        var failedSteps = await jobRepository.GetFailedJobStepsAsync(
            profile,
            hours,
            null,
            cancellationToken);

        var report = new NightlyReport
        {
            ProfileName = profile.Name,
            TimelineEvents = timeline.ToList(),
            FailedJobs = failedJobs.ToList(),
            FailedSteps = failedSteps.ToList(),
            Summary = BuildSummary(timeline, failedJobs, failedSteps, hours, null, null)
        };

        return report;
    }

    public async Task<IncidentReport> BuildIncidentReportAsync(
        ServerProfile profile,
        DateTime? from,
        DateTime? to,
        int? hours,
        string? containsText,
        CancellationToken cancellationToken = default)
    {
        var timeline = await timelineService.GetTimelineAsync(
            new TimelineRequest
            {
                Profile = profile,
                From = from,
                To = to,
                Hours = hours,
                ContainsText = containsText
            },
            cancellationToken);

        var effectiveHours = hours ?? CalculateHoursFallback(from, to);

        var failedJobs = await jobRepository.GetFailedJobsAsync(
            profile,
            effectiveHours,
            containsText,
            cancellationToken);

        var failedSteps = await jobRepository.GetFailedJobStepsAsync(
            profile,
            effectiveHours,
            containsText,
            cancellationToken);

        if (!string.IsNullOrWhiteSpace(containsText))
        {
            failedJobs = failedJobs
                .Where(x =>
                    x.JobName.Contains(containsText, StringComparison.OrdinalIgnoreCase) ||
                    x.Message.Contains(containsText, StringComparison.OrdinalIgnoreCase))
                .ToList();

            failedSteps = failedSteps
                .Where(x =>
                    x.JobName.Contains(containsText, StringComparison.OrdinalIgnoreCase) ||
                    x.StepName.Contains(containsText, StringComparison.OrdinalIgnoreCase) ||
                    x.Message.Contains(containsText, StringComparison.OrdinalIgnoreCase))
                .ToList();
        }

        if (from.HasValue || to.HasValue)
        {
            failedJobs = failedJobs
                .Where(x => IsWithinRange(x.RunDateTime, from, to))
                .ToList();

            failedSteps = failedSteps
                .Where(x => IsWithinRange(x.RunDateTime, from, to))
                .ToList();
        }

        var report = new IncidentReport
        {
            ProfileName = profile.Name,
            SearchText = containsText,
            TimelineEvents = timeline.ToList(),
            FailedJobs = failedJobs.ToList(),
            FailedSteps = failedSteps.ToList(),
            Summary = BuildSummary(timeline, failedJobs, failedSteps, effectiveHours, from, to)
        };

        return report;
    }

    private static ReportSummary BuildSummary(
        IReadOnlyList<TimelineEvent> timeline,
        IReadOnlyList<JobExecution> failedJobs,
        IReadOnlyList<JobStepExecution> failedSteps,
        int? hours,
        DateTime? from,
        DateTime? to)
    {
        return new ReportSummary
        {
            TotalTimelineEvents = timeline.Count,
            ErrorEvents = timeline.Count(x => x.Severity == EventSeverity.Error),
            CriticalEvents = timeline.Count(x => x.Severity == EventSeverity.Critical),
            FailedJobs = failedJobs.Count,
            FailedSteps = failedSteps.Count,
            From = from ?? (hours.HasValue ? DateTime.Now.AddHours(-hours.Value) : null),
            To = to ?? DateTime.Now
        };
    }

    private static bool IsWithinRange(DateTime? value, DateTime? from, DateTime? to)
    {
        if (!value.HasValue)
        {
            return false;
        }

        if (from.HasValue && value.Value < from.Value)
        {
            return false;
        }

        if (to.HasValue && value.Value > to.Value)
        {
            return false;
        }

        return true;
    }

    private static int CalculateHoursFallback(DateTime? from, DateTime? to)
    {
        if (from.HasValue && to.HasValue)
        {
            return Math.Max(1, (int)Math.Ceiling((to.Value - from.Value).TotalHours));
        }

        return 24;
    }
}