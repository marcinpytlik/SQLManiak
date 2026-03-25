using System.Text.RegularExpressions;

namespace SqlStressLab.Core.Templates;

public static class PlaceholderEngine
{
    private static readonly Regex PlaceholderRegex = new(@"\{\{(?<name>[A-Za-z0-9_]+)\}\}", RegexOptions.Compiled);

    public static string Replace(string input, IReadOnlyDictionary<string, string> variables)
    {
        return PlaceholderRegex.Replace(input, match =>
        {
            var name = match.Groups["name"].Value;

            if (variables.TryGetValue(name, out var value))
                return value;

            return match.Value;
        });
    }
}