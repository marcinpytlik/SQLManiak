using System.Text.Json;
using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Templates;

public static class TemplateResolver
{
    public static RootConfig Resolve(string templateJson, IReadOnlyDictionary<string, string> variables)
    {
        var resolvedJson = PlaceholderEngine.Replace(templateJson, variables);

        var config = JsonSerializer.Deserialize<RootConfig>(resolvedJson, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        return config ?? throw new InvalidOperationException("Nie udało się zbudować RootConfig z template.");
    }
}