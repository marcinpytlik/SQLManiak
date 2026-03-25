namespace SqlStressLab.Core.Models;

public sealed class MatrixCombination
{
    public int Index { get; set; }
    public Dictionary<string, string> Variables { get; set; } = new(StringComparer.OrdinalIgnoreCase);
}