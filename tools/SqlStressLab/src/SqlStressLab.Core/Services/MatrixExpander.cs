using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Services;

public sealed class MatrixExpander
{
    public List<Dictionary<string, string>> Expand(MatrixDefinition matrix)
    {
        ArgumentNullException.ThrowIfNull(matrix);

        var result = new List<Dictionary<string, string>>();

        if (matrix.Dimensions is null || matrix.Dimensions.Count == 0)
        {
            result.Add(new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase));
            return result;
        }

        var dimensions = matrix.Dimensions.ToList();

        void Recurse(int index, Dictionary<string, string> current)
        {
            if (index >= dimensions.Count)
            {
                result.Add(new Dictionary<string, string>(current, StringComparer.OrdinalIgnoreCase));
                return;
            }

            var (key, values) = (dimensions[index].Key, dimensions[index].Value);

            if (values is null || values.Count == 0)
            {
                current[key] = string.Empty;
                Recurse(index + 1, current);
                current.Remove(key);
                return;
            }

            foreach (var value in values)
            {
                current[key] = value;
                Recurse(index + 1, current);
            }

            current.Remove(key);
        }

        Recurse(0, new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase));
        return result;
    }
}