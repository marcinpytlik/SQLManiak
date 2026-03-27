using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Core.Abstractions;

public interface ISqlConnectionTester
{
    Task<ConnectionTestResult> TestAsync(ConnectionProfile profile, CancellationToken cancellationToken = default);
}