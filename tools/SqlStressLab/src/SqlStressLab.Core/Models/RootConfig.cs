namespace SqlStressLab.Core.Models;

public sealed class RootConfig
{
    public string ProfileName { get; set; } = "default";
    public string ScenarioName { get; set; } = "General";
    public SqlAuthOptions Connection { get; set; } = new();
    public ExecutionConfig Execution { get; set; } = new();
    public List<SqlParameterDefinition>? Parameters { get; set; }
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
public BundleOptions Bundle { get; set; } = new();
public ConsoleReportOptions ConsoleReport { get; set; } = new();
public PerfCounterOptions PerfCounters { get; set; } = new();
public XeCaptureOptions XeCapture { get; set; } = new();
public DryRunOptions DryRun { get; set; } = new();
public PublishBundleOptions PublishBundle { get; set; } = new();
public SqlStressLab.Core.Hooks.HookOptions Hooks { get; set; } = new();
}