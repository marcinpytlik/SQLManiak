namespace SqlStressLab.Core.Models;

public sealed class MatrixDefinition
{
    public string Name { get; set; } = "default-matrix";
    public bool StopOnError { get; set; } = true;
    public List<MatrixAxis> Axes { get; set; } = new();
}