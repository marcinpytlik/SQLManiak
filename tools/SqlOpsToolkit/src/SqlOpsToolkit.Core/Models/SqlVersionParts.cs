namespace SqlOpsToolkit.Core.Models;

public sealed class SqlVersionParts
{
    public int? Major { get; init; }
    public int? Minor { get; init; }
    public int? Build { get; init; }
    public int? Revision { get; init; }

    public bool IsValid =>
        Major.HasValue &&
        Minor.HasValue &&
        Build.HasValue &&
        Revision.HasValue;
}