using SqlStressLab.Core.Models;

namespace SqlStressLab.Core.Templates;

public static class MatrixExpander
{
    public static List<MatrixCombination> Expand(MatrixDefinition definition)
    {
        var results = new List<MatrixCombination>();
        int index = 1;

        void Recurse(int axisIndex, Dictionary<string, string> current)
        {
            if (axisIndex >= definition.Axes.Count)
            {
                results.Add(new MatrixCombination
                {
                    Index = index++,
                    Variables = new Dictionary<string, string>(current, StringComparer.OrdinalIgnoreCase)
                });
                return;
            }

            var axis = definition.Axes[axisIndex];

            foreach (var value in axis.Values)
            {
                current[axis.Name] = value;
                Recurse(axisIndex + 1, current);
            }
        }

        Recurse(0, new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase));
        return results;
    }
}