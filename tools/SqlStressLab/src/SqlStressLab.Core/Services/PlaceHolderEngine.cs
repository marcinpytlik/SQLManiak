namespace SqlStressLab.Core.Services;

public static class PlaceholderEngine
{
    public static string Apply(string input, IReadOnlyDictionary<string, string> variables)
    {
        if (string.IsNullOrWhiteSpace(input))
            return input;

        var result = input;

        foreach (var kvp in variables)
        {
            var token1 = "{{" + kvp.Key + "}}";
            var token2 = "${" + kvp.Key + "}";

            result = result.Replace(token1, kvp.Value ?? string.Empty, StringComparison.OrdinalIgnoreCase);
            result = result.Replace(token2, kvp.Value ?? string.Empty, StringComparison.OrdinalIgnoreCase);
        }

        return result;
    }
}