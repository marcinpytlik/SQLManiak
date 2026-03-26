using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Core.Interfaces;

public interface IConnectionTestService
{
    Task<ConnectionTestResult> TestAsync(ServerProfile profile, CancellationToken cancellationToken = default);
}