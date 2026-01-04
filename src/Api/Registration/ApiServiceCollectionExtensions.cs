using Application.Interfaces;
using Infrastructure.Messaging;
using Infrastructure.Persistence.Registration;
using MediatR;
using Microsoft.Extensions.DependencyInjection;
using MassTransit;

namespace Api.Registration;

public static class ApiServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        services.AddMediatR(cfg => cfg.RegisterServicesFromAssemblyContaining<Application.Commands.PublishMessage.PublishMessageCommand>());
        return services;
    }

    public static IServiceCollection AddInfrastructureMessaging(this IServiceCollection services)
    {
        services.AddMassTransit(x =>
        {
            x.AddConsumer<Api.Consumers.DemoMessageConsumer>();

            x.UsingRabbitMq((context, cfg) =>
            {
                cfg.Host("localhost", "/", h =>
                {
                    h.Username("guest");
                    h.Password("guest");
                });

                cfg.ReceiveEndpoint("demo-queue", e =>
                {
                    e.ConfigureConsumer<Api.Consumers.DemoMessageConsumer>(context);
                    e.PrefetchCount = 16;
                    e.UseMessageRetry(r => r.Interval(3, TimeSpan.FromSeconds(2)));
                });
            });
        });

        services.AddScoped<IMessagePublisher, MessagingService>();

        return services;
    }

    public static IServiceCollection AddPersistenceServices(this IServiceCollection services)
    {
        services.AddPersistence();
        return services;
    }
}
