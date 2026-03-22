namespace SqlStressLab.Core.Models;

public sealed class SqlOutputOptions
{
    public bool Enabled { get; set; } = false;
    public string ConnectionMode { get; set; } = "SameAsTarget"; // SameAsTarget / Separate
    public SqlAuthOptions? Connection { get; set; }
}