using Application.Interfaces;
using Domain.Entities;
using MassTransit;

namespace Infrastructure.Messaging;

public class MessagingService : IMessagePublisher
{
    private readonly IPublishEndpoint _publishEndpoint;

    public MessagingService(IPublishEndpoint publishEndpoint)
    {
        _publishEndpoint = publishEndpoint;
    }

    public async Task PublishAsync(DemoMessage message)
    {
        await _publishEndpoint.Publish(message);
    }
}