using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class TrendCommandService
{
    public Task<int> ExecuteAsync(
        CliArguments args,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(args);

        // Docelowo: analiza trendu ostatnich N runów
        return Task.FromResult(0);
    }
}