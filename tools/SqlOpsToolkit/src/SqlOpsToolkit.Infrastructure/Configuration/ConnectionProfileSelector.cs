using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Configuration;

public static class ConnectionProfileSelector
{
    public static IReadOnlyList<ConnectionProfile> Select(
        IReadOnlyList<ConnectionProfile> profiles,
        string? profileName,
        string? tag)
    {
        IEnumerable<ConnectionProfile> query = profiles;

        if (!string.IsNullOrWhiteSpace(profileName))
        {
            query = query.Where(p => string.Equals(p.Name, profileName, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(tag))
        {
            query = query.Where(p => p.Tags.Any(t => string.Equals(t, tag, StringComparison.OrdinalIgnoreCase)));
        }

        return query.ToList();
    }
}