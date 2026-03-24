using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class RunCommandService
{
    public Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        // Docelowo tu trafia pełna obsługa komendy run.
        return Task.FromResult(0);
    }
}