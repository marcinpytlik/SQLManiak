using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SqlOpsLogParser.Cli.Commands;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;
using SqlOpsLogParser.Infrastructure.Configuration;
using SqlOpsLogParser.Infrastructure.Connection;
using SqlOpsLogParser.Infrastructure.Repositories;
using SqlOpsLogParser.Infrastructure.Services;

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
        services.AddSingleton<CliApplication>();

        return services;
    }
}