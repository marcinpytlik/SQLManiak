using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Core.Abstractions;

public interface IPatchBaselineLoader
{
    Task<PatchBaseline> LoadAsync(string path, CancellationToken cancellationToken = default);
}