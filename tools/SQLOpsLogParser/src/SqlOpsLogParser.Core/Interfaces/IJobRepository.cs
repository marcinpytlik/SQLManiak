using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IJobRepository
{
    Task<IReadOnlyList<JobInfo>> GetJobsAsync(
        ServerProfile profile,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<JobExecution>> GetFailedJobsAsync(
        ServerProfile profile,
        int hours,
        string? jobName = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<JobExecution>> GetJobHistoryAsync(
        ServerProfile profile,
        string jobName,
        int? top = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<JobStepInfo>> GetJobStepsAsync(
        ServerProfile profile,
        string jobName,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<JobStepExecution>> GetFailedJobStepsAsync(
        ServerProfile profile,
        int hours,
        string? jobName = null,
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<JobStepExecution>> GetJobStepHistoryAsync(
        ServerProfile profile,
        string jobName,
        int? top = null,
        CancellationToken cancellationToken = default);
}