using System.Text.RegularExpressions;

namespace SqlStressLab.Core.Diagnostics;

public static class PlaceholderCheck
{
    private static readonly Regex PlaceholderRegex = new(@"\{\{(?<name>[A-Za-z0-9_]+)\}\}", RegexOptions.Compiled);

    public static List<string> FindUnresolved(string input)
    {
        return PlaceholderRegex.Matches(input)
            .Select(x => x.Value)
            .Distinct()
            .ToList();
    }
}