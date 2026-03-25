namespace SqlStressLab.Core.Regression;

public sealed class RegressionPolicy
{
    public string Name { get; set; } = "default-regression";
    public List<RegressionRule> Rules { get; set; } = new();
}