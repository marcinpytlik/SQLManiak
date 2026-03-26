using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IErrorLogReader
{
    Task<IReadOnlyList<SqlLogEntry>> ReadAsync(
        ErrorLogReadRequest request,
        CancellationToken cancellationToken = default);
}