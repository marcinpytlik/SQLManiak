namespace SqlStressLab.Core.Models;

public sealed class RootConfig
{
    public string ProfileName { get; set; } = "default-profile";
    public string ScenarioName { get; set; } = "General";

    public SqlAuthOptions Connection { get; set; } = new();
    public ExecutionConfig Execution { get; set; } = new();
    public List<SqlParameterDefinition> Parameters { get; set; } = new();
    public OutputOptions Output { get; set; } = new();
    public RetryOptions Retry { get; set; } = new();
    public SqlOutputOptions SqlOutput { get; set; } = new();
    public RunLifecycleOptions Lifecycle { get; set; } = new();
    public EnvironmentInfo Environment { get; set; } = new();
    public MarkdownReportOptions MarkdownReport { get; set; } = new();
    public TagOptions Tags { get; set; } = new();
    public HtmlReportOptions HtmlReport { get; set; } = new();

    public CompareOptions Compare { get; set; } = new();
    public TrendOptions Trend { get; set; } = new();

    public BatchConfig Batch { get; set; } = new();
    public RunbookConfig Runbook { get; set; } = new();
    public BundleOptions Bundle { get; set; } = new();
    public PublishBundleOptions PublishBundle { get; set; } = new();
public List<EnvironmentProfile> Environments { get; set; } = new();
public List<ScenarioPackDefinition> ScenarioPacks { get; set; } = new();
    public PerfCountersOptions PerfCounters { get; set; } = new();
}