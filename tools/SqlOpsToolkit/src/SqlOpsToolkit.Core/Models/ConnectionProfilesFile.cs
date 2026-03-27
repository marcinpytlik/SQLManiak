namespace SqlOpsToolkit.Core.Models;

public sealed class ConnectionProfilesFile
{
    public IReadOnlyList<ConnectionProfile> Profiles { get; init; } = Array.Empty<ConnectionProfile>();
}