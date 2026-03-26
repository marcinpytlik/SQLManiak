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
        CancellationToken cancellationToken = default);

    Task<IReadOnlyList<JobExecution>> GetJobHistoryAsync(
        ServerProfile profile,
        string jobName,
        int? top = null,
        CancellationToken cancellationToken = default);
}