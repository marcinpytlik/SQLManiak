using System.Text.Json;
using System.Text.Json.Serialization;
using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Configuration;

public sealed class JsonConnectionProfileLoader : IConnectionProfileLoader
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
        Converters =
        {
            new JsonStringEnumConverter()
        }
    };

    public async Task<ConnectionProfilesFile> LoadAsync(string path, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(path))
            throw new ArgumentException("Path do pliku profili nie może być pusty.", nameof(path));

        if (!File.Exists(path))
            throw new FileNotFoundException("Nie znaleziono pliku profili.", path);

        await using var stream = File.OpenRead(path);
        var result = await JsonSerializer.DeserializeAsync<ConnectionProfilesFile>(stream, JsonOptions, cancellationToken);

        if (result is null)
            throw new InvalidOperationException("Nie udało się zdeserializować pliku profili.");

        return result;
    }
}