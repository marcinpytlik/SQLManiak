using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using SqlOpsLogParser.Core.Models;

namespace SqlOpsLogParser.Cli.Composition;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationServices(
        this IServiceCollection services,
        IConfiguration configuration)
    {
        services.Configure<ProfilesOptions>(configuration);

        services.AddSingleton<CliApplication>();

        return services;
    }
}