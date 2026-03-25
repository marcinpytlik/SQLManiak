namespace SqlStressLab.Core.Regression;

public sealed class RegressionCheckResult
{
    public string CurrentRunId { get; set; } = "";
    public string BaselineRunId { get; set; } = "";
    public string Verdict { get; set; } = "PASS";
    public List<string> Messages { get; set; } = new();
}