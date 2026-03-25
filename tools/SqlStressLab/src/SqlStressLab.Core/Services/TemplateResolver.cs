using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class TemplateResolver
{
    public async Task<string> RenderTemplateAsync(
        string rootProfilePath,
        TemplateProfile template,
        CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(rootProfilePath);
        ArgumentNullException.ThrowIfNull(template);

        var rootDirectory = Path.GetDirectoryName(Path.GetFullPath(rootProfilePath))
                            ?? Directory.GetCurrentDirectory();

        var baseProfilePath = template.BaseProfilePath;
        if (string.IsNullOrWhiteSpace(baseProfilePath))
            throw new InvalidOperationException($"Template '{template.Name}' nie ma BaseProfilePath.");

        if (!Path.IsPathRooted(baseProfilePath))
            baseProfilePath = Path.GetFullPath(Path.Combine(rootDirectory, baseProfilePath));

        if (!File.Exists(baseProfilePath))
            throw new FileNotFoundException($"Brak base profile: {baseProfilePath}");

        var baseJson = await File.ReadAllTextAsync(baseProfilePath, cancellationToken);
        return PlaceholderEngine.Apply(baseJson, template.Variables);
    }

    public RootConfig DeserializeRenderedConfig(string renderedJson)
    {
        var config = JsonSerializer.Deserialize<RootConfig>(renderedJson, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        if (config is null)
            throw new InvalidOperationException("Nie udało się zdeserializować renderowanego template.");

        return config;
    }
}