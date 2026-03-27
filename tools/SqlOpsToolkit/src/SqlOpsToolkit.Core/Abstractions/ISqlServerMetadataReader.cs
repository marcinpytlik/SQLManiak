using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Core.Abstractions;

public interface ISqlServerMetadataReader
{
    Task<SqlServerInstanceMetadata> ReadAsync(ConnectionProfile profile, CancellationToken cancellationToken = default);
}