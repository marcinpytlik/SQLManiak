using SqlOpsLogParser.Core.Enums;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Services;

public sealed class TimelineService(
    IErrorLogReader errorLogReader,
    IJobRepository jobRepository) : ITimelineService
{
    public async Task<IReadOnlyList<TimelineEvent>> GetTimelineAsync(
        TimelineRequest request,
        CancellationToken cancellationToken = default)
    {
        var from = request.From;
        var to = request.To;

        if (!from.HasValue && request.Hours.HasValue)
        {
            from = DateTime.Now.AddHours(-request.Hours.Value);
        }

        if (!to.HasValue)
        {
            to = DateTime.Now;
        }

        var result = new List<TimelineEvent>();

        if (!request.SourceFilter.HasValue || request.SourceFilter == TimelineSourceType.ErrorLog)
        {
            var logEntries = await errorLogReader.ReadAsync(
                new ErrorLogReadRequest
                {
                    Profile = request.Profile,
                    LogNumber = 0,
                    From = from,
                    To = to,
                    Top = null,
                    ContainsText = request.ContainsText
                },
                cancellationToken);

            result.AddRange(logEntries.Select(MapErrorLogEntry));
        }

        var hoursWindow = request.Hours ?? CalculateHoursFallback(from, to);

        if (!request.SourceFilter.HasValue || request.SourceFilter == TimelineSourceType.FailedJobs)
        {
            var failedJobs = await jobRepository.GetFailedJobsAsync(
                request.Profile,
                hoursWindow,
                null,
                cancellationToken);

            result.AddRange(failedJobs
                .Where(x => IsWithinRange(x.RunDateTime, from, to))
                .Select(MapFailedJob));
        }

        if (!request.SourceFilter.HasValue || request.SourceFilter == TimelineSourceType.FailedSteps)
        {
            var failedSteps = await jobRepository.GetFailedJobStepsAsync(
                request.Profile,
                hoursWindow,
                null,
                cancellationToken);

            result.AddRange(failedSteps
                .Where(x => IsWithinRange(x.RunDateTime, from, to))
                .Select(MapFailedStep));
        }

        if (request.OnlyErrors)
        {
            result = result
                .Where(x =>
                    x.Severity == EventSeverity.Error ||
                    x.Severity == EventSeverity.Critical)
                .ToList();
        }

        if (!string.IsNullOrWhiteSpace(request.ContainsText))
        {
            var needle = request.ContainsText.Trim();

            result = result
                .Where(x =>
                    (x.Title?.Contains(needle, StringComparison.OrdinalIgnoreCase) ?? false) ||
                    (x.Message?.Contains(needle, StringComparison.OrdinalIgnoreCase) ?? false) ||
                    (x.JobName?.Contains(needle, StringComparison.OrdinalIgnoreCase) ?? false) ||
                    (x.StepName?.Contains(needle, StringComparison.OrdinalIgnoreCase) ?? false))
                .ToList();
        }

        result = result
            .OrderBy(x => x.EventTime)
            .ToList();

        if (request.Top is > 0)
        {
            result = result.Take(request.Top.Value).ToList();
        }

        return result;
    }

    private static TimelineEvent MapErrorLogEntry(SqlLogEntry entry)
    {
        return new TimelineEvent
        {
            EventTime = entry.LogDate,
            Source = TimelineSourceType.ErrorLog,
            Severity = entry.Severity,
            Category = entry.Category,
            Title = entry.ProcessInfo,
            Message = entry.Text,
            ProcessInfo = entry.ProcessInfo
        };
    }

    private static TimelineEvent MapFailedJob(JobExecution job)
    {
        return new TimelineEvent
        {
            EventTime = job.RunDateTime ?? DateTime.MinValue,
            Source = TimelineSourceType.FailedJobs,
            Severity = EventSeverity.Error,
            Category = EventCategory.Agent,
            Title = $"Job failed: {job.JobName}",
            Message = job.Message,
            JobName = job.JobName
        };
    }

    private static TimelineEvent MapFailedStep(JobStepExecution step)
    {
        return new TimelineEvent
        {
            EventTime = step.RunDateTime ?? DateTime.MinValue,
            Source = TimelineSourceType.FailedSteps,
            Severity = EventSeverity.Error,
            Category = EventCategory.Agent,
            Title = $"Step failed: {step.StepName}",
            Message = step.Message,
            JobName = step.JobName,
            StepName = step.StepName
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
            var diff = to.Value - from.Value;
            return Math.Max(1, (int)Math.Ceiling(diff.TotalHours));
        }

        return 24;
    }
}