using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IErrorLogRepository
{
    Task<IReadOnlyList<SqlErrorLogInfo>> GetErrorLogsAsync(
        ServerProfile profile,
        CancellationToken cancellationToken = default);
}