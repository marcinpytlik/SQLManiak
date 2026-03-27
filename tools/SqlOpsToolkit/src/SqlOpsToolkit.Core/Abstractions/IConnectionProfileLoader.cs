using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Core.Abstractions;

public interface IConnectionProfileLoader
{
    Task<ConnectionProfilesFile> LoadAsync(string path, CancellationToken cancellationToken = default);
}