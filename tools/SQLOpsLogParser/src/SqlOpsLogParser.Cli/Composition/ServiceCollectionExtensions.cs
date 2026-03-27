using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SqlOpsLogParser.Cli.Commands;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;
using SqlOpsLogParser.Infrastructure.Configuration;
using SqlOpsLogParser.Infrastructure.Connection;
using SqlOpsLogParser.Infrastructure.Repositories;
using SqlOpsLogParser.Infrastructure.Services;
using SqlOpsLogParser.Reporting;


namespace SqlOpsLogParser.Cli.Composition;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<ProfilesOptions>(configuration);

        services.AddSingleton<IProfileProvider, JsonProfileProvider>();
        services.AddSingleton<ISqlConnectionFactory, SqlConnectionFactory>();
        services.AddSingleton<IConnectionTestService, ConnectionTestService>();
        services.AddSingleton<IErrorLogRepository, ErrorLogRepository>();

        services.AddSingleton<ProfilesCommandHandler>();
        services.AddSingleton<ErrorLogCommandHandler>();
        services.AddSingleton<IErrorLogReader, ErrorLogReader>();
        services.AddSingleton<ILogEntryClassifier, LogEntryClassifier>();
        services.AddSingleton<IJobRepository, JobRepository>();
services.AddSingleton<JobsCommandHandler>();
services.AddSingleton<ITimelineService, TimelineService>();
services.AddSingleton<TimelineCommandHandler>();
services.AddSingleton<IReportWriter, MarkdownReportWriter>();
services.AddSingleton<IReportWriter, JsonReportWriter>();
services.AddSingleton<IReportWriter, CsvReportWriter>();
services.AddSingleton<IReportWriterFactory, ReportWriterFactory>();
services.AddSingleton<IReportService, ReportService>();
        services.AddSingleton<CliApplication>();

        return services;
    }
}