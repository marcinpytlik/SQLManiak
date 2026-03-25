namespace SqlStressLab.Core.Models;

public sealed class MatrixDefinition
{
    public string Name { get; set; } = "";
    public string BaseProfilePath { get; set; } = "";

    public List<MatrixAxisDefinition> Axes { get; set; } = new();

    // opcjonalna zgodność wsteczna, jeśli gdzieś jeszcze używasz Dimensions
    public Dictionary<string, List<string>> Dimensions
    {
        get => Axes.ToDictionary(
            x => x.Name,
            x => x.Values,
            StringComparer.OrdinalIgnoreCase);
        set
        {
            Axes = value?
                .Select(kvp => new MatrixAxisDefinition
                {
                    Name = kvp.Key,
                    Values = kvp.Value ?? new List<string>()
                })
                .ToList()
                ?? new List<MatrixAxisDefinition>();
        }
    }
}