using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SqlOpsLogParser.Core.Interfaces;
using SqlOpsLogParser.Core.Models;
using SqlOpsLogParser.Infrastructure.Configuration;
using SqlOpsLogParser.Infrastructure.Connection;
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
        services.AddSingleton<CliApplication>();

        return services;
    }
}