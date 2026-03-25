namespace SqlStressLab.Core.Templates;

public static class VariableResolver
{
    public static Dictionary<string, string> Merge(
        IDictionary<string, string>? templateDefaults,
        IDictionary<string, string>? environmentVariables,
        IDictionary<string, string>? localOverrides,
        IDictionary<string, string>? envVars,
        IDictionary<string, string>? cliOverrides)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        Apply(result, templateDefaults);
        Apply(result, environmentVariables);
        Apply(result, localOverrides);
        Apply(result, envVars);
        Apply(result, cliOverrides);

        return result;
    }

    private static void Apply(Dictionary<string, string> target, IDictionary<string, string>? source)
    {
        if (source is null)
            return;

        foreach (var kv in source)
        {
            target[kv.Key] = kv.Value;
        }
    }
}