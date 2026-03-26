using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface ITimelineService
{
    Task<IReadOnlyList<TimelineEvent>> GetTimelineAsync(
        TimelineRequest request,
        CancellationToken cancellationToken = default);
}