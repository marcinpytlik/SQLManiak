using Microsoft.Extensions.Options;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Infrastructure.Configuration;

public sealed class JsonProfileProvider(IOptions<ProfilesOptions> options) : IProfileProvider
{
    private readonly ProfilesOptions _options = options.Value;

    public IReadOnlyList<ServerProfile> GetAll()
        => _options.Profiles;

    public ServerProfile? GetByName(string name)
        => _options.Profiles.FirstOrDefault(x =>
            string.Equals(x.Name, name, StringComparison.OrdinalIgnoreCase));
}