using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class CompareCommandService
{
    public Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        // Docelowo: porównanie current vs baseline
        return Task.FromResult(0);
    }
}