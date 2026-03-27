using System.Text.Json;
using SqlOpsToolkit.Core.Abstractions;
using SqlOpsToolkit.Core.Models;

namespace SqlOpsToolkit.Infrastructure.Configuration;

public sealed class JsonPatchBaselineLoader : IPatchBaselineLoader
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true
    };

    public async Task<PatchBaseline> LoadAsync(string path, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(path))
            throw new ArgumentException("Path do pliku baseline nie może być pusty.", nameof(path));

        if (!File.Exists(path))
            throw new FileNotFoundException("Nie znaleziono pliku baseline.", path);

        await using var stream = File.OpenRead(path);
        var result = await JsonSerializer.DeserializeAsync<PatchBaseline>(stream, JsonOptions, cancellationToken);

        if (result is null)
            throw new InvalidOperationException("Nie udało się zdeserializować pliku baseline.");

        return result;
    }
}